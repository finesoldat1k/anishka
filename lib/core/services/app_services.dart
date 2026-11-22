// Single interface for all app services.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/metadata/shikimori.dart';
import '../api/service_registry.dart';
import '../api/sources/anilibme.dart';
import '../api/sources/anilibria.dart';
import '../api/sources/animevost.dart';
import '../api/sources/embed/aksor_resolver.dart';
import '../api/sources/embed/alloha_resolver.dart';
import '../api/sources/embed/aniboom_resolver.dart';
import '../api/sources/embed/cdnvideohub_resolver.dart';
import '../api/sources/embed/embed_resolver.dart';
import '../api/sources/embed/kodik_resolver.dart';
import '../api/sources/embed/sibnet_resolver.dart';
import '../api/sources/hdrezka.dart';
import '../api/sources/kodik.dart';
import '../api/sources/resolved_stream.dart';
import '../api/sources/sameband.dart';
import '../api/sources/yani.dart' as yani_src;
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
        _persistent = PersistentCache(prefs),
        _embedResolvers = EmbedResolverRegistry([
          KodikResolver(),
          AniboomResolver(),
          SibnetResolver(),
          CdnVideoHubResolver(),
          AksorResolver(),
          AllohaResolver(),
        ]) {
    _cache.usePersistent(_persistent);
    _rebuildRegistry();
    _settings.addListener(_onSettingsChanged);
  }

  final ServiceSettingsStore _settings;
  final UnifiedCache _cache;
  final PersistentCache _persistent;
  final EmbedResolverRegistry _embedResolvers;

  ApiServiceRegistry _registry = _emptyRegistry();
  late UnifiedRepository _repository;

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

  /// Resolve an episode stream URL (URL-only convenience wrapper).
  Future<String?> resolveStream(
    AnimeEpisode episode, {
    String quality = 'auto',
  }) async {
    final stream = await resolveStreamDetailed(episode, quality: quality);
    return stream?.url;
  }

  /// Resolve an episode to a direct stream with playback headers.
  ///
  /// Order:
  /// 1. Direct HLS/MP4 URL already attached to the episode.
  /// 2. Embed resolver registered for `resolverSource` (Kodik, Aniboom, ...).
  /// 3. Source provider implementing [StreamResolvableSourceProvider]
  ///    (HDRezka and Kodik's lazy API).
  /// 4. Embed resolver matched by URL (`resolverId`/`embedUrl`).
  Future<ResolvedStream?> resolveStreamDetailed(
    AnimeEpisode episode, {
    String quality = 'auto',
  }) async {
    final direct = episode.hlsForQuality(quality) ?? episode.streamUrl;
    if (direct != null && direct.isNotEmpty) {
      return ResolvedStream(
        url: direct,
        headers: episode.streamHeaders,
        kind: StreamKind.fromUrl(direct),
      );
    }
    if (!episode.canResolve) return null;

    final resolverSource = episode.resolverSource!;
    final resolverId = episode.resolverId!;
    final embedUrl = episode.embedUrl?.trim() ?? '';

    final cacheKey = CacheKeys.resolvedStreamDetail(
      resolverSource,
      resolverId,
      quality,
    );
    final cached = _cache.get<ResolvedStream>(cacheKey);
    if (cached != null) return cached;

    ResolvedStream? stream;

    // 1. Dedicated embed resolver (Kodik, Aniboom, Sibnet, CVH, Aksor).
    final embedResolver = _embedResolvers.byId(resolverSource);
    if (embedResolver != null) {
      stream = await _safeResolve(
        () => embedResolver.resolve(resolverId, quality: quality),
      );
      if (stream == null && embedUrl.isNotEmpty) {
        stream = await _safeResolve(
          () => embedResolver.resolve(embedUrl, quality: quality),
        );
      }
    }

    // 2. Provider-level lazy resolution (HDRezka).
    if (stream == null) {
      final provider = _registry.getSourceProvider(resolverSource);
      if (provider is StreamResolvableSourceProvider) {
        stream = await _safeResolve(
          () => (provider as StreamResolvableSourceProvider).resolveStream(
            resolverId,
            ordinal: episode.ordinal,
            quality: quality,
          ),
        );
      }
    }

    // 3. Match a resolver by the URL itself.
    stream ??= await _safeResolve(
      () => _embedResolvers.resolve(resolverId, quality: quality),
    );
    if (stream == null && embedUrl.isNotEmpty) {
      stream = await _safeResolve(
        () => _embedResolvers.resolve(embedUrl, quality: quality),
      );
    }

    if (stream != null && stream.isPlayable) {
      _cache.set(cacheKey, stream, ttl: const Duration(hours: 1));
    }
    return stream;
  }

  Future<ResolvedStream?> _safeResolve(
    Future<ResolvedStream?> Function() action,
  ) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
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
      streamResolverDetailed: _resolveStreamDetailed,
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
      Kodik(),
      HDRezka(),
      AnimeVost(),
      SameBand(),
      AnilibMe(),
    ];
  }

  Future<ResolvedStream?> _resolveStreamDetailed(
    AnimeEpisode episode, {
    required String quality,
  }) {
    return resolveStreamDetailed(episode, quality: quality);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
