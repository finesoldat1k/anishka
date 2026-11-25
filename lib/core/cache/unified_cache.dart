// Unified cache service with TTL support and request deduplication.

import 'dart:async';
import 'dart:convert';

import 'persistent_cache.dart';

/// Generic cache entry with expiration.
class CacheEntry<T> {
  const CacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// In-memory cache with TTL and request deduplication.
///
/// Features:
/// - TTL-based expiration
/// - Request deduplication (prevents duplicate in-flight requests)
/// - Generic type support
/// - Cache statistics
/// - Offline-first persistent layer (disk) for API responses
class UnifiedCache {
  final Map<String, CacheEntry<Object?>> _cache = {};
  final Map<String, Completer<Object?>> _pending = {};
  final Map<String, int> _hitCount = {};
  final Map<String, int> _missCount = {};

  /// Optional persistent (disk) layer for offline-first API responses.
  PersistentCache? persistent;

  /// Attach a persistent cache so API responses survive restarts.
  void usePersistent(PersistentCache cache) => persistent = cache;

  CacheEntry<Object?>? _freshEntry(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) return null;
    return entry;
  }

  void _recordHit(String key) {
    _hitCount[key] = (_hitCount[key] ?? 0) + 1;
  }

  void _recordMiss(String key) {
    _missCount[key] = (_missCount[key] ?? 0) + 1;
  }

  /// Get cached value if fresh, otherwise execute [loader].
  ///
  /// Concurrent callers share a single in-flight request, including
  /// [forceRefresh] callers: a refresh storm must not hit the network twice.
  Future<T> getOrLoad<T>(
    String key,
    Future<T> Function() loader, {
    required Duration ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final entry = _freshEntry(key);
      if (entry != null && entry.value is T) {
        _recordHit(key);
        return entry.value as T;
      }
    }

    final pending = _pending[key];
    if (pending != null) {
      return await pending.future as T;
    }

    return _load<T>(key, loader, ttl);
  }

  Future<T> _load<T>(
    String key,
    Future<T> Function() loader,
    Duration ttl, {
    Future<void> Function(T value)? persist,
  }) async {
    _recordMiss(key);

    final completer = Completer<Object?>();
    _pending[key] = completer;

    try {
      final value = await loader();
      // Only publish the result if this request is still the current one.
      // An invalidation or a newer refresh must not be overwritten by a slow
      // response that started earlier.
      if (identical(_pending[key], completer)) {
        _cache[key] = CacheEntry<Object?>(
          value: value,
          expiresAt: DateTime.now().add(ttl),
        );
        if (persist != null) {
          try {
            await persist(value);
          } catch (_) {
            // Disk cache is best-effort and must never break the caller.
          }
        }
      }
      completer.complete(value);
      return value;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      // A newer request for the same key may have replaced this one.
      if (identical(_pending[key], completer)) _pending.remove(key);
    }
  }

  /// Offline-first variant of [getOrLoad].
  ///
  /// Resolution order:
  /// 1. In-memory cache (fresh).
  /// 2. In-flight request (deduplication).
  /// 3. Persistent (disk) cache — served even without network.
  /// 4. [loader] — result written to both memory and persistent cache.
  ///
  /// [encoder] is optional; when provided the value is JSON-encoded before
  /// persisting. [decoder] decodes the persisted JSON back to [T].
  Future<T> getOrLoadPersistent<T>({
    required String key,
    required Future<T> Function() loader,
    required Duration ttl,
    T Function(dynamic json)? decoder,
    Object Function(T)? encoder,
    bool forceRefresh = false,
  }) async {
    // 1. Fresh memory value.
    if (!forceRefresh) {
      final entry = _freshEntry(key);
      if (entry != null && entry.value is T) {
        _recordHit(key);
        return entry.value as T;
      }
    }

    // 2. Join an in-flight request.
    final pending = _pending[key];
    if (pending != null) {
      return await pending.future as T;
    }

    // 3. Persistent (offline-first). Preserve the remaining disk TTL instead
    //    of extending it to a full [ttl] on every read.
    if (!forceRefresh && persistent != null && decoder != null) {
      try {
        final entry = persistent!.readEntry(key);
        if (entry != null) {
          final cached = decoder(jsonDecode(entry.value));
          _recordHit(key);
          _cache[key] = CacheEntry<Object?>(
            value: cached,
            expiresAt: entry.expiresAt,
          );
          return cached;
        }
      } catch (_) {
        // Corrupted or incompatible payload — drop it and load fresh data.
        try {
          await persistent!.remove(key);
        } catch (_) {
          // Disk cache is best-effort.
        }
      }
    }

    // 4. Load and write through to disk.
    final persistentCache = persistent;
    final value = await _load<T>(
      key,
      loader,
      ttl,
      persist: persistentCache == null || encoder == null
          ? null
          : (value) =>
                persistentCache.writeRaw(key, jsonEncode(encoder(value)), ttl),
    );
    return value;
  }

  /// Get cached value without loading.
  T? get<T>(String key) {
    final entry = _freshEntry(key);
    if (entry != null && entry.value is T) {
      _recordHit(key);
      return entry.value as T;
    }
    _recordMiss(key);
    return null;
  }

  /// Set cache value directly.
  void set<T>(String key, T value, {required Duration ttl}) {
    _cache[key] = CacheEntry<Object?>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Invalidate a specific key.
  void invalidate(String key) {
    _cache.remove(key);
    _pending.remove(key);
  }

  /// Invalidate keys matching a predicate.
  void invalidateWhere(bool Function(String key) predicate) {
    final keysToRemove = _cache.keys.where(predicate).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _pending.remove(key);
    }
  }

  /// Clear all cache.
  void clear() {
    _cache.clear();
    _pending.clear();
    _hitCount.clear();
    _missCount.clear();
  }

  /// Check if key has fresh cached value.
  bool hasFresh(String key) => _freshEntry(key) != null;

  /// Get cache statistics.
  CacheStats getStats() {
    return CacheStats(
      totalEntries: _cache.length,
      pendingRequests: _pending.length,
      hits: _hitCount.values.fold(0, (a, b) => a + b),
      misses: _missCount.values.fold(0, (a, b) => a + b),
    );
  }

  /// Remove expired entries.
  void cleanupExpired() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((e) => e.value.expiresAt.isBefore(now))
        .map((e) => e.key)
        .toList();
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }
}

/// Cache statistics.
class CacheStats {
  const CacheStats({
    required this.totalEntries,
    required this.pendingRequests,
    required this.hits,
    required this.misses,
  });

  final int totalEntries;
  final int pendingRequests;
  final int hits;
  final int misses;

  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0;

  @override
  String toString() =>
      'CacheStats(entries: $totalEntries, pending: $pendingRequests, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}

/// Cache key builders for consistent key generation.
class CacheKeys {
  // Metadata
  static String shikimoriPopular(
    String order,
    String? status,
    String? kind,
    int limit, [
    int page = 1,
  ]) => 'shikimori:popular:$order|${status ?? ''}|${kind ?? ''}|$limit|p$page';

  static String shikimoriSearch(String query) =>
      'shikimori:search:${query.toLowerCase().trim()}';

  static String shikimoriDetails(int id) => 'shikimori:details:$id';

  static String shikimoriScreenshots(int id) => 'shikimori:screenshots:$id';

  static String shikimoriFranchise(String franchise, int limit) =>
      'shikimori:franchise:$franchise:$limit';

  // Enriched metadata
  static String animeMetadata(int shikimoriId) => 'metadata:anime:$shikimoriId';

  static String yaniDetails(int shikimoriId) => 'yani:details:$shikimoriId';

  /// Base details resolved through a title search when Shikimori is down.
  static String fallbackDetails(int shikimoriId) =>
      'metadata:fallback:$shikimoriId';

  // Sources
  static String anilibriaReleases(int shikimoriId, String? nameHint) =>
      'anilibria:releases:$shikimoriId:${nameHint ?? ''}';

  static String anilibriaRelease(int id) => 'anilibria:release:$id';

  static String yaniBundle(int shikimoriId, List<String> queries) =>
      'yani:bundle:$shikimoriId:${queries.join('|')}';

  static String sourceSearch(String sourceId, String query) =>
      'source:$sourceId:search:${query.toLowerCase().trim()}';

  static String sourceDetails(String sourceId, String externalId) =>
      'source:$sourceId:details:$externalId';

  // Unified
  static String animeWithSources(int shikimoriId) =>
      'unified:anime:$shikimoriId';

  static String sourcesByShikimori(int shikimoriId) =>
      'unified:sources:$shikimoriId';

  // Resolved streams
  static String resolvedStream(
    String resolverSource,
    String resolverId,
    String quality,
  ) => 'stream:$resolverSource:$resolverId:$quality';

  static String resolvedStreamDetail(
    String resolverSource,
    String resolverId,
    String quality,
  ) => 'stream:detail:$resolverSource:$resolverId:$quality';
}
