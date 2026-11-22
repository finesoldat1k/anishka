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
  final Map<String, CacheEntry<Object>> _cache = {};
  final Map<String, Completer<Object>> _pending = {};
  final Map<String, int> _hitCount = {};
  final Map<String, int> _missCount = {};

  /// Optional persistent (disk) layer for offline-first API responses.
  PersistentCache? persistent;

  /// Attach a persistent cache so API responses survive restarts.
  void usePersistent(PersistentCache cache) => persistent = cache;

  /// Get cached value if fresh, otherwise execute [loader].
  Future<T> getOrLoad<T>(
    String key,
    Future<T> Function() loader, {
    required Duration ttl,
    bool forceRefresh = false,
  }) async {
    // Return fresh cached value
    if (!forceRefresh) {
      final entry = _cache[key] as CacheEntry<T>?;
      if (entry != null && !entry.isExpired) {
        _hitCount[key] = (_hitCount[key] ?? 0) + 1;
        return entry.value;
      }
    }

    // Return in-flight request if exists
    if (!forceRefresh) {
      final pending = _pending[key];
      if (pending != null) {
        return pending.future as Future<T>;
      }
    }

    _missCount[key] = (_missCount[key] ?? 0) + 1;

    // Create new request with deduplication
    final completer = Completer<Object>();
    _pending[key] = completer;

    try {
      final value = await loader();
      _cache[key] = CacheEntry<T>(value: value, expiresAt: DateTime.now().add(ttl)) as CacheEntry<Object>;
      completer.complete(value as Object);
      return value;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pending.remove(key);
    }
  }

  /// Offline-first variant of [getOrLoad].
  ///
  /// Resolution order:
  /// 1. Persistent (disk) cache — served immediately when offline.
  /// 2. In-memory cache (fresh).
  /// 3. In-flight request (deduplication).
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
    // 1. Persistent (offline-first) — served even without network.
    if (!forceRefresh && persistent != null && decoder != null) {
      try {
        final cached = persistent!.read(key, decoder);
        if (cached != null) {
          _hitCount[key] = (_hitCount[key] ?? 0) + 1;
          // Seed memory cache too for fast subsequent reads.
          _cache[key] = CacheEntry<T>(value: cached, expiresAt: DateTime.now().add(ttl)) as CacheEntry<Object>;
          return cached;
        }
      } catch (_) {
        // Fall through to network.
      }
    }

    // 2-4. In-memory / loader path.
    final value = await getOrLoad(key, loader, ttl: ttl, forceRefresh: forceRefresh);

    // Write through to persistent cache.
    if (persistent != null && encoder != null) {
      await persistent!
          .writeRaw(key, jsonEncode(encoder(value)), ttl)
          .catchError((_) {});
    }

    return value;
  }

  /// Get cached value without loading.
  T? get<T>(String key) {
    final entry = _cache[key] as CacheEntry<T>?;
    if (entry != null && !entry.isExpired) {
      _hitCount[key] = (_hitCount[key] ?? 0) + 1;
      return entry.value;
    }
    _missCount[key] = (_missCount[key] ?? 0) + 1;
    return null;
  }

  /// Set cache value directly.
  void set<T>(String key, T value, {required Duration ttl}) {
    _cache[key] = CacheEntry<T>(value: value, expiresAt: DateTime.now().add(ttl)) as CacheEntry<Object>;
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
  bool hasFresh(String key) {
    final entry = _cache[key];
    return entry != null && !entry.isExpired;
  }

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
  static String shikimoriPopular(String order, String? status, String? kind, int limit) =>
      'shikimori:popular:$order|${status ?? ''}|${kind ?? ''}|$limit';

  static String shikimoriSearch(String query) =>
      'shikimori:search:${query.toLowerCase().trim()}';

  static String shikimoriDetails(int id) =>
      'shikimori:details:$id';

  static String shikimoriScreenshots(int id) =>
      'shikimori:screenshots:$id';

  static String shikimoriFranchise(String franchise, int limit) =>
      'shikimori:franchise:$franchise:$limit';

  // Enriched metadata
  static String animeMetadata(int shikimoriId) =>
      'metadata:anime:$shikimoriId';

  static String yaniDetails(int shikimoriId) =>
      'yani:details:$shikimoriId';

  // Sources
  static String anilibriaReleases(int shikimoriId, String? nameHint) =>
      'anilibria:releases:$shikimoriId:${nameHint ?? ''}';

  static String anilibriaRelease(int id) =>
      'anilibria:release:$id';

  static String yaniBundle(int shikimoriId, List<String> queries) =>
      'yani:bundle:$shikimoriId:${queries.join('|')}';

  static String sourceSearch(String sourceId, String query) =>
      'source:$sourceId:search:${query.toLowerCase().trim()}';

  static String sourceDetails(String sourceId, String externalId) =>
      'source:$sourceId:details:$externalId';

  // Unified
  static String animeWithSources(int shikimoriId) =>
      'unified:anime:$shikimoriId';

  // Resolved streams
  static String resolvedStream(String resolverSource, String resolverId, String quality) =>
      'stream:$resolverSource:$resolverId:$quality';
}

/// Global cache instance.
final unifiedCache = UnifiedCache();