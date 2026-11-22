// Single interface for all app services.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/metadata/shikimori.dart';
import '../api/service_registry.dart';
import '../api/sources/anidub.dart';
import '../api/sources/anilibme.dart';
import '../api/sources/anilibria.dart';
import '../api/sources/animevost.dart';
import '../api/sources/sameband.dart';
import '../api/sources/yani.dart' as yani_src;
import '../api/sources/yummyanime.dart';
import '../cache/cache_service.dart';
import '../cache/persistent_cache.dart';
import '../cache/unified_cache.dart' hide CacheStats;
import '../models/anime_episode.dart';
import '../repository/unified_repository.dart';
import '../storage/service_settings_store.dart';
import '../utils/errors.dart';

/// Health result for a single service.
class ServiceHealth {
  const ServiceHealth({
    required this.id,
    required this.ok,
    this.latency,
    this.error,
  });

  final String id;
  final bool ok;
  final Duration? latency;
  final String? error;
}

/// Aggregated health of all services.
class ServicesHealth {
  const ServicesHealth({
    required this.metadata,
    required this.sources,
  });

  final List<ServiceHealth> metadata;
  final List<ServiceHealth> sources;

  bool get allOk =>
      metadata.every((h) => h.ok) && sources.every((h) => h.ok);
}

/// Single services interface (ChangeNotifier).
class AppServices extends ChangeNotifier {
  AppServices({
    required SharedPreferences prefs,
  })  : _settings = ServiceSettingsStore(prefs),
        _cache = UnifiedCache(),
        _persistent = PersistentCache(prefs) {
    _cache.usePersistent(_persistent);
    _rebuildRegistry();
    _settings.addListener(_onSettingsChanged);
  }

  final ServiceSettingsStore _settings;
  final UnifiedCache _cache;
  final PersistentCache _persistent;

  ApiServiceRegistry _registry = _emptyRegistry();
  late final UnifiedRepository _repository;

  static ApiServiceRegistry _emptyRegistry() => ApiServiceRegistry(
        metadata: MetadataProviderRegistry.create(
          providers: const [],
          enabledIds: const {},
        ),
        sources: SourceProviderRegistry.create(
          providers: const [],
          enabledIds: const {},
        ),
      );

  // ============ public interface ============

  /// The single repository used by the whole UI layer.
  UnifiedRepository get repository => _repository;

  /// Metadata registry (all providers).
  ApiServiceRegistry get registry => _registry;

  /// Currently enabled metadata providers.
  List<MetadataProvider> get enabledMetadata => _registry.enabledMetadata;

  /// All metadata providers (enabled + disabled).
  List<MetadataProvider> get allMetadata => _registry.allMetadata;

  /// Currently enabled source providers.
  List<SourceProvider> get enabledSources => _registry.enabledSources;

  /// All source providers (enabled + disabled).
  List<SourceProvider> get allSources => _registry.allSources;

  bool isMetadataEnabled(String id) => _registry.isMetadataEnabled(id);
  bool isSourceEnabled(String id) => _registry.isSourceEnabled(id);

  /// Persisted cache stats (memory + disk + image cache).
  Future<CacheStats> cacheStats() => CacheService.stats();

  /// Number of persistent API-cache entries.
  int get persistentCacheCount => _persistent.count;

  // ============ toggles ============

  /// Enable/disable a metadata provider. Persisted and reflected in the
  /// registry immediately; listeners are notified.
  Future<void> toggleMetadata(String id, bool enabled) async {
    await _settings.toggleMetadata(id, enabled);
    _rebuildRegistry();
    notifyListeners();
  }

  /// Enable/disable a source provider. Persisted and reflected in the
  /// registry immediately; listeners are notified.
  Future<void> toggleSource(String id, bool enabled) async {
    await _settings.toggleSource(id, enabled);
    _rebuildRegistry();
    notifyListeners();
  }

  /// Reset all service settings to defaults (all providers enabled).
  Future<void> resetSettings() async {
    await _settings.reset();
    _rebuildRegistry();
    notifyListeners();
  }

  // ============ health ============

  /// Check the health of every registered provider with short timeouts.
  Future<ServicesHealth> healthCheck() async {
    final meta = <ServiceHealth>[];
    for (final p in _registry.allMetadata) {
      meta.add(await _checkMetadata(p));
    }
    final src = <ServiceHealth>[];
    for (final p in _registry.allSources) {
      src.add(await _checkSource(p));
    }
    return ServicesHealth(metadata: meta, sources: src);
  }

  Future<ServiceHealth> _checkMetadata(MetadataProvider p) async {
    final stopwatch = Stopwatch()..start();
    try {
      await p.search(query: 'test', limit: 1).timeout(const Duration(seconds: 8));
      return ServiceHealth(id: p.id, ok: true, latency: stopwatch.elapsed);
    } catch (e) {
      return ServiceHealth(
        id: p.id,
        ok: false,
        latency: stopwatch.elapsed,
        error: userMessage(e),
      );
    }
  }

  Future<ServiceHealth> _checkSource(SourceProvider p) async {
    final stopwatch = Stopwatch()..start();
    try {
      await p.search('test').timeout(const Duration(seconds: 8));
      return ServiceHealth(id: p.id, ok: true, latency: stopwatch.elapsed);
    } catch (e) {
      return ServiceHealth(
        id: p.id,
        ok: false,
        latency: stopwatch.elapsed,
        error: userMessage(e),
      );
    }
  }

  // ============ cache ============

  /// Clear every cache layer (memory, persistent disk, images).
  Future<void> clearCache() async {
    _cache.clear();
    await _persistent.clear();
    await CacheService.clear();
    notifyListeners();
  }

  /// Remove expired entries from the memory cache.
  void cleanupExpired() {
    _cache.cleanupExpired();
    notifyListeners();
  }

  // ============ stream resolution ============

  /// Resolve an episode stream URL. Tries direct URLs first, then the
  /// registered source provider (single interface), then a legacy fallback.
  Future<String?> resolveStream(AnimeEpisode episode, {String quality = 'auto'}) async {
    final direct = episode.hlsForQuality(quality) ?? episode.streamUrl;
    if (direct != null && direct.isNotEmpty) return direct;
    if (!episode.canResolve) return null;

    final cacheKey = 'stream:${episode.resolverSource}:${episode.resolverId}:$quality';
    final cached = _cache.get<String>(cacheKey);
    if (cached != null) return cached;

    String? url;
    try {
      // Single-interface path: ask the owning source provider for the source.
      final provider = _registry.getSourceProvider(episode.resolverSource!);
      if (provider != null) {
        final source = await provider
            .getSource(episode.resolverId!)
            .timeout(const Duration(seconds: 10));
        if (source != null) {
          final match = source.episodes.firstWhere(
            (e) => e.ordinal == episode.ordinal,
            orElse: () => source.episodes.first,
          );
          url = match.hlsForQuality(quality);
        }
      }
    } catch (_) {
      // No legacy fallback — sources provide their own streams.
    }

    if (url != null && url.isNotEmpty) {
      _cache.set(cacheKey, url, ttl: const Duration(hours: 1));
    }
    return url;
  }

  // ============ internals ============

  void _rebuildRegistry() {
    final metadataProviders = _buildMetadataProviders();
    final sourceProviders = _buildSourceProviders();

    final enabledMetadata = _settings.getEnabledMetadata().toSet();
    final enabledSources = _settings.getEnabledSources().toSet();

    _registry = ApiServiceRegistry(
      metadata: MetadataProviderRegistry.create(
        providers: metadataProviders,
        enabledIds: enabledMetadata,
      ),
      sources: SourceProviderRegistry.create(
        providers: sourceProviders,
        enabledIds: enabledSources,
      ),
    );
    _repository = UnifiedRepository(
      registry: _registry,
      cache: _cache,
      streamResolver: _resolveStream,
    );
  }

  void _onSettingsChanged() {
    _rebuildRegistry();
    notifyListeners();
  }

  List<MetadataProvider> _buildMetadataProviders() {
    return [
      Shikimori(),
    ];
  }

  List<SourceProvider> _buildSourceProviders() {
    return [
      AniLibria(),
      yani_src.Yani(),
      AnimeVost(),
      SameBand(),
      YummyAnime(),
      AnilibMe(),
      AniDub(),
    ];
  }

  Future<String?> _resolveStream(
    AnimeEpisode episode, {
    required String quality,
  }) async {
    return resolveStream(episode, quality: quality);
  }

  @override
  void dispose() {
    super.dispose();
  }
}


