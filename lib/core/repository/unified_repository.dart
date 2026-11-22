// Unified repository - the single data layer for the whole app.
//
// Orchestrates metadata providers (catalog/search/details/enrichment) and
// source providers (video playback) behind one interface. Every call is
// fault-tolerant: a dead or slow source never blocks the page, results are
// cached in memory + disk (offline-first), and transient failures are
// retried with short, bounded timeouts.

import 'dart:async';

import '../api/metadata/shikimori.dart';
import '../api/service_registry.dart';
import '../api/sources/resolved_stream.dart';
import '../api/sources/yani.dart' as yani_src;
import '../cache/unified_cache.dart';
import '../models/anime_episode.dart';
import '../models/anime_franchise.dart';
import '../models/anime_release.dart';
import '../models/anime_source.dart';
import '../models/shikimori_anime.dart';
import '../models/voiceover.dart';

/// TTL constants.
const _detailsTtl = Duration(minutes: 30);
const _metadataTtl = Duration(minutes: 15);
const _sourcesTtl = Duration(minutes: 15);
const _animeWithSourcesTtl = Duration(minutes: 15);
const _screenshotsTtl = Duration(hours: 6); // Screenshots rarely change
const _franchiseTtl = Duration(hours: 12);  // Franchise relations rarely change

/// Unified repository using the provider architecture.
class UnifiedRepository {
  UnifiedRepository({
    required this._registry,
    required this._cache,
    this._streamResolver,
    this._streamResolverDetailed,
  });

  final ApiServiceRegistry _registry;
  final UnifiedCache _cache;

  /// Resolve an episode stream URL (injected by [AppServices]).
  final Future<String?> Function(AnimeEpisode, {required String quality})?
      _streamResolver;

  /// Resolve an episode stream with playback headers (injected by [AppServices]).
  final Future<ResolvedStream?> Function(
    AnimeEpisode, {
    required String quality,
  })? _streamResolverDetailed;

  // ============ retry / timeout helpers ============

  /// Run [action] with up to [attempts] attempts and a per-attempt timeout.
  /// The last error is thrown if every attempt fails.
  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int attempts = 2,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    Exception? last;
    for (var i = 0; i < attempts; i++) {
      try {
        return await action().timeout(timeout);
      } catch (e) {
        last = e is Exception ? e : Exception(e.toString());
      }
    }
    throw last!;
  }

  /// Run [action] best-effort: never throws, returns [onError] (default null)
  /// on any failure. Used for optional enrichment that must not block the page.
  Future<T?> _safe<T>(Future<T?> Function() action, {T? onError}) async {
    try {
      return await action();
    } catch (_) {
      return onError;
    }
  }

  // ============ cached loaders ============

  /// Get cached popular/ongoing list if fresh, otherwise load and cache.
  Future<List<ShikimoriAnime>> getPopular({
    bool refresh = false,
    int limit = 50,
    String order = 'popularity',
    String? status,
    String? kind,
  }) async {
    final cacheKey = CacheKeys.shikimoriPopular(order, status, kind, limit);
    if (!refresh && _cache.hasFresh(cacheKey)) {
      final cached = _cache.get<List<ShikimoriAnime>>(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
    }

    final providers = _registry.enabledMetadata;
    if (providers.isEmpty) return const [];

    // Try providers in priority order (sequential, not parallel)
    for (final provider in providers) {
      try {
        final list = await _loadPopularFromProvider(
          provider,
          limit,
          order,
          status,
          kind,
        );
        if (list.isNotEmpty) {
          _registry.reportMetadataSuccess(provider.id);
          _cache.set(cacheKey, list.take(limit).toList(), ttl: const Duration(minutes: 10));
          return list.take(limit).toList();
        }
      } catch (e) {
        _registry.reportMetadataFailure(provider.id);
        continue;
      }
    }
    return const [];
  }

  /// Load popular items from a single provider with retry.
  Future<List<ShikimoriAnime>> _loadPopularFromProvider(
    MetadataProvider provider,
    int limit,
    String order,
    String? status,
    String? kind,
  ) async {
    if (provider is Shikimori) {
      final list = await _withRetry(
        () => provider.getPopular(
          limit: limit, order: order, status: status, kind: kind,
        ),
        attempts: 2,
        timeout: const Duration(seconds: 8),
      );
      return list
          .map(_convertToShikimoriAnime)
          .where((anime) => anime.id > 0)
          .toList();
    } else {
      // Other providers: search for popular anime
      final list = await _safe<List<UnifiedMetadata>>(
        () => provider.search(query: 'popular', limit: limit),
        onError: const <UnifiedMetadata>[],
      );
      return (list ?? const []).map(_convertToShikimoriAnime).toList();
    }
  }

  Future<List<UnifiedMetadata>> search({
    required String query,
    bool refresh = false,
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final cacheKey = CacheKeys.shikimoriSearch(trimmed);
    if (!refresh && _cache.hasFresh(cacheKey)) {
      final cached = _cache.get<List<UnifiedMetadata>>(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
    }

    final providers = _registry.enabledMetadata;
    if (providers.isEmpty) return const [];

    // Try providers in priority order. First successful provider wins.
    for (final provider in providers) {
      try {
        final list = await _withRetry<List<UnifiedMetadata>>(
          () => provider.search(query: trimmed, limit: limit),
          attempts: 2,
          timeout: const Duration(seconds: 8),
        );
        if (list.isNotEmpty) {
          _registry.reportMetadataSuccess(provider.id);
          _cache.set(cacheKey, list.take(limit).toList(), ttl: const Duration(minutes: 5));
          return list.take(limit).toList();
        }
      } catch (e) {
        _registry.reportMetadataFailure(provider.id);
        continue;
      }
    }
    return const [];
  }

  /// Search Shikimori, returning legacy [ShikimoriAnime] items for UI.
  Future<List<ShikimoriAnime>> searchShikimori(
    String query, {
    bool refresh = false,
  }) async {
    final results = await search(query: query, refresh: refresh);
    return results.map(_convertToShikimoriAnime).toList();
  }

  /// Base details — try Shikimori first, then AniList/Jikan/Yani fallback.
  /// [titleHint] is used when Shikimori is down to search fallback providers.
  Future<ShikimoriAnimeDetails> getShikimoriDetails(
    int id, {
    bool refresh = false,
    String? titleHint,
  }) async {
    final base = await getBaseDetails(id, refresh: refresh, titleHint: titleHint);
    if (base == null) {
      throw Exception('Аниме не найдено: $id');
    }
    return _convertToShikimoriDetails(base);
  }

  /// Enriched details — all providers contribute all fields.
  Future<ShikimoriAnimeDetails> getAnimeDetails(
    int id, {
    bool refresh = false,
  }) async {
    final enriched = await getEnrichedMetadata(id, refresh: refresh);
    return _convertToShikimoriDetails(enriched);
  }

  /// Last fully loaded result, if it is still fresh.
  AnimeWithSources? cachedAnimeWithSources(int shikimoriId) {
    final cacheKey = CacheKeys.animeWithSources(shikimoriId);
    if (!_cache.hasFresh(cacheKey)) return null;
    return _cache.get<AnimeWithSources>(cacheKey);
  }

  /// Get base details from any available provider.
  ///
  /// Shikimori is preferred (has canonical shikimoriId), but if it's down,
  /// AniList, Jikan or Yani can supply title/poster/description using [titleHint].
  Future<UnifiedMetadata?> getBaseDetails(
    int shikimoriId, {
    bool refresh = false,
    String? titleHint,
  }) async {
    final providers = _registry.enabledMetadata;
    if (providers.isEmpty) return null;

    // 1. Try Shikimori first (canonical ID).
    final shikimori = _registry.getMetadataProvider('shikimori') as Shikimori?;
    if (shikimori != null) {
      try {
        final cacheKey = CacheKeys.shikimoriDetails(shikimoriId);
        final result = await _cache.getOrLoadPersistent<UnifiedMetadata>(
          key: cacheKey,
          loader: () async {
            final details = await _withRetry<UnifiedMetadata?>(
              () => shikimori.getDetails(shikimoriId),
              attempts: 2,
              timeout: const Duration(seconds: 8),
            );
            if (details == null) {
              throw Exception('Аниме не найдено в Shikimori: $shikimoriId');
            }
            return details;
          },
          ttl: _detailsTtl,
          forceRefresh: refresh,
          decoder: (json) => UnifiedMetadata.fromJson(json as Map<String, dynamic>),
          encoder: (value) => value.toJson(),
        );
        if (result.shikimoriId > 0) return result;
      } catch (_) {
        // Fall through to other providers.
      }
    }

    // 2. Try all remaining providers in parallel using titleHint search.
    //    Shikimori IDs don't map to AniList/Jikan internal IDs, so we search by title.
    final otherProviders = providers.where((p) => p.id != 'shikimori').toList();
    if (titleHint != null && titleHint.isNotEmpty) {
      final results = await Future.wait(otherProviders.map((p) async {
        try {
          final list = await p.search(query: titleHint, limit: 5).timeout(
                const Duration(seconds: 8),
              );
          return list.where((m) => m.title.isNotEmpty).toList();
        } catch (_) {
          return <UnifiedMetadata>[];
        }
      }));
      for (final list in results) {
        if (list.isNotEmpty) return list.first;
      }
    }

    // 3. Try Yani by shikimoriId directly (Yani indexes by shikimori_id).
    final yani = _registry.getMetadataProvider('yani');
    if (yani != null) {
      try {
        final cacheKey = CacheKeys.yaniDetails(shikimoriId);
        final result = await _cache.getOrLoadPersistent<UnifiedMetadata>(
          key: cacheKey,
          loader: () async {
            final byId = await yani.getDetails(shikimoriId).timeout(
                  const Duration(seconds: 8),
                );
            if (byId != null && byId.title.isNotEmpty) return byId;
            throw Exception('Аниме не найдено в Yani: $shikimoriId');
          },
          ttl: _detailsTtl,
          forceRefresh: refresh,
          decoder: (json) => UnifiedMetadata.fromJson(json as Map<String, dynamic>),
          encoder: (value) => value.toJson(),
        );
        if (result.title.isNotEmpty) return result;
      } catch (_) {}
    }

    return null;
  }

  Future<List<String>> getScreenshots(
    int shikimoriId, {
    bool refresh = false,
  }) async {
    // Check cache first
    final cacheKey = CacheKeys.shikimoriScreenshots(shikimoriId);
    if (!refresh) {
      final cached = _cache.get<List<String>>(cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    // Only try providers that actually support screenshots (Shikimori, Yani)
    final screenshotProviders = _registry.enabledMetadata
        .where((p) => p.id == 'shikimori' || p.id == 'yani')
        .toList();

    if (screenshotProviders.isEmpty) return const [];

    // Try providers in priority order (sequential, but only 2 providers max)
    for (final provider in screenshotProviders) {
      try {
        final list = await _withRetry<List<String>>(
          () => provider.getScreenshots(shikimoriId),
          attempts: 1, // Reduced attempts for screenshots
          timeout: const Duration(seconds: 6), // Reduced timeout
        );
        if (list.isNotEmpty) {
          _cache.set(cacheKey, list, ttl: _screenshotsTtl);
          return list;
        }
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  Future<List<UnifiedMetadata>> getRelatedByFranchise(
    String franchise, {
    bool refresh = false,
    int limit = 30,
  }) async {
    // Check cache first
    final cacheKey = CacheKeys.shikimoriFranchise(franchise, limit);
    if (!refresh) {
      final cached = _cache.get<List<UnifiedMetadata>>(cacheKey);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    // Only Shikimori implements getRelatedByFranchise
    final shikimori = _registry.getMetadataProvider('shikimori');
    if (shikimori == null) return const [];

    try {
      final items = await _withRetry<List<UnifiedMetadata>>(
        () => shikimori.getRelatedByFranchise(franchise, limit: limit),
        attempts: 1,
        timeout: const Duration(seconds: 6),
      );
      if (items.isNotEmpty) {
        _cache.set(cacheKey, items, ttl: _franchiseTtl);
        return items;
      }
    } catch (_) {
      // Fall through
    }
    return const [];
  }

  // ============ enriched metadata — all providers contribute ============

  /// Enriched metadata — every enabled provider contributes all fields.
  ///
  /// Merge priority: base provider wins for identity fields (shikimoriId,
  /// title), but every other field is filled from the first provider that has
  /// it. If Shikimori is down, Jikan/Yani posters/descriptions are used.
  Future<UnifiedMetadata> getEnrichedMetadata(
    int shikimoriId, {
    bool refresh = false,
  }) async {
    final cacheKey = CacheKeys.animeMetadata(shikimoriId);
    return _cache.getOrLoadPersistent<UnifiedMetadata>(
      key: cacheKey,
      loader: () => _buildEnrichedMetadata(shikimoriId),
      ttl: _metadataTtl,
      forceRefresh: refresh,
      decoder: (json) => UnifiedMetadata.fromJson(json as Map<String, dynamic>),
      encoder: (value) => value.toJson(),
    );
  }

  Future<UnifiedMetadata> _buildEnrichedMetadata(int shikimoriId) async {
    final base = await getBaseDetails(shikimoriId);
    if (base == null) {
      throw Exception('Аниме не найдено: $shikimoriId');
    }

    final providers = _registry.enabledMetadata
        .where((p) => p.id != 'shikimori')
        .toList();

    // Parallel enrichment — every provider is best-effort.
    final futures = <Future<UnifiedMetadata?>>[];
    for (final provider in providers) {
      futures.add(
        _safe(() => provider.getDetails(shikimoriId)).then((m) => m),
      );
    }

    final results = await Future.wait(futures);

    // Also get screenshots from all providers.
    final screenshotsFuture = getScreenshots(shikimoriId);
    final screenshots = await screenshotsFuture;

    return _mergeMetadata(
      base,
      results.whereType<UnifiedMetadata>().toList(),
      screenshots,
    );
  }

  /// Merge metadata from multiple providers into one unified record.
  ///
  /// Identity (shikimoriId, title) comes from [base]. Every other field is
  /// filled from the first enrichment provider that has a non-null value.
  /// This way if Shikimori lacks a poster but Jikan has it, Jikan's poster
  /// is used. If Shikimori is down entirely, Yani's data fills the gaps.
  UnifiedMetadata _mergeMetadata(
    UnifiedMetadata base,
    List<UnifiedMetadata> enrichments,
    List<String> screenshots,
  ) {
    String? posterUrl = base.posterUrl;
    String? backgroundUrl = base.backgroundUrl;
    double? score = base.score;
    int? year = base.year;
    int? episodes = base.episodes;
    int? duration = base.duration;
    String? description = base.description;
    String? englishTitle = base.englishTitle;
    String? japaneseTitle = base.japaneseTitle;
    String? status = base.status;
    String? kind = base.kind;
    String? ageRating = base.ageRating;
    List<String> genres = base.genres;
    List<String> studios = base.studios;
    List<String> allScreenshots = [...base.screenshots, ...screenshots];

    for (final m in enrichments) {
      posterUrl ??= m.posterUrl;
      backgroundUrl ??= m.backgroundUrl;
      score ??= m.score;
      year ??= m.year;
      episodes ??= m.episodes;
      duration ??= m.duration;
      description ??= m.description;
      englishTitle ??= m.englishTitle;
      japaneseTitle ??= m.japaneseTitle;
      status ??= m.status;
      kind ??= m.kind;
      ageRating ??= m.ageRating;
      if (genres.isEmpty && m.genres.isNotEmpty) genres = m.genres;
      if (studios.isEmpty && m.studios.isNotEmpty) studios = m.studios;
      allScreenshots.addAll(m.screenshots);
    }

    final uniqueScreenshots = allScreenshots.toSet().toList();

    return base.copyWith(
      posterUrl: posterUrl,
      backgroundUrl: backgroundUrl,
      score: score,
      year: year,
      episodes: episodes,
      duration: duration,
      description: description,
      englishTitle: englishTitle,
      japaneseTitle: japaneseTitle,
      status: status,
      kind: kind,
      ageRating: ageRating,
      genres: genres,
      studios: studios,
      screenshots: uniqueScreenshots,
    );
  }

  List<String> _buildSearchQueries(UnifiedMetadata base) {
    final queries = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return;
      if (queries.any((q) => q.toLowerCase() == text.toLowerCase())) return;
      queries.add(text);
    }

    add(base.title);
    add(base.englishTitle);
    add(base.japaneseTitle);
    return queries.take(3).toList();
  }

  // ============ video sources ============

  /// Find video sources by Shikimori ID, ordered by priority.
  Future<List<UnifiedSource>> findSourcesByShikimoriId(
    int shikimoriId, {
    bool refresh = false,
    String? nameHint,
  }) async {
    final cacheKey = CacheKeys.sourcesByShikimori(shikimoriId);
    if (!refresh && _cache.hasFresh(cacheKey)) {
      final cached = _cache.get<List<UnifiedSource>>(cacheKey);
      if (cached != null) return cached;
    }

    final sources = await _loadAllSources(shikimoriId, nameHint: nameHint);
    _cache.set(cacheKey, sources, ttl: _sourcesTtl);
    return sources;
  }

  Future<List<UnifiedSource>> _loadAllSources(
    int shikimoriId, {
    String? nameHint,
  }) async {
    final base = await _safe<UnifiedMetadata>(
      () => getBaseDetails(shikimoriId, titleHint: nameHint),
    );

    final queries = <String>[];
    void addQuery(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return;
      if (queries.any((item) => item.toLowerCase() == text.toLowerCase())) {
        return;
      }
      queries.add(text);
    }

    if (base != null) {
      for (final query in _buildSearchQueries(base)) {
        addQuery(query);
      }
    }
    addQuery(nameHint);

    final providers = _registry.enabledSources;
    final futures = <Future<List<UnifiedSource>>>[];
    for (final provider in providers) {
      futures.add(
        _safe<List<UnifiedSource>>(
          () => _loadFromProvider(provider, shikimoriId, base, queries),
          onError: const <UnifiedSource>[],
        ).then((result) => result ?? const <UnifiedSource>[]),
      );
    }

    final results = await Future.wait(futures);
    final allSources = <UnifiedSource>[];
    for (final sources in results) {
      allSources.addAll(sources);
    }

    allSources.sort((a, b) => _sourcePriority(a.providerId)
        .compareTo(_sourcePriority(b.providerId)));
    return allSources;
  }

  Future<List<UnifiedSource>> _loadFromProvider(
    SourceProvider provider,
    int shikimoriId,
    UnifiedMetadata? base,
    List<String> queries,
  ) async {
    // Yani keeps a dedicated lookup: its API indexes Shikimori ids and groups
    // videos by studio, which the generic provider contract cannot express.
    if (provider is yani_src.Yani) {
      final fetched = await provider
          .findSources(shikimoriId, queries: queries)
          .timeout(const Duration(seconds: 20));
      return fetched ?? const [];
    }

    final hint = base?.title ?? (queries.isEmpty ? null : queries.first);

    // 1. Preferred path: provider knows how to map a Shikimori id.
    try {
      final found = await provider
          .findByShikimoriId(shikimoriId, nameHint: hint)
          .timeout(const Duration(seconds: 20));
      final usable = await _expandSources(provider, found);
      if (usable.isNotEmpty) return usable;
    } catch (_) {
      // Fall back to title search.
    }

    // 2. Title search fallback for providers without Shikimori mapping.
    for (final query in queries.take(3)) {
      try {
        final results = await provider
            .search(query)
            .timeout(const Duration(seconds: 15));
        final best = _bestTitleMatch(results, query, base);
        if (best == null) continue;
        final expanded = await _expandSource(provider, best);
        if (expanded != null && expanded.episodes.isNotEmpty) {
          return [expanded];
        }
      } catch (_) {
        // Try the next title variant.
      }
    }
    return const [];
  }

  Future<List<UnifiedSource>> _expandSources(
    SourceProvider provider,
    List<UnifiedSource> sources,
  ) async {
    final result = <UnifiedSource>[];
    for (final source in sources) {
      final expanded = await _expandSource(provider, source);
      if (expanded != null && expanded.episodes.isNotEmpty) {
        result.add(expanded);
      }
    }
    return result;
  }

  Future<UnifiedSource?> _expandSource(
    SourceProvider provider,
    UnifiedSource source,
  ) async {
    if (source.episodes.isNotEmpty) return source;
    try {
      final full = await provider
          .getSource(source.id)
          .timeout(const Duration(seconds: 20));
      if (full != null) return full;
    } catch (_) {
      // Keep the lightweight search result.
    }
    return source;
  }

  UnifiedSource? _bestTitleMatch(
    List<UnifiedSource> sources,
    String query,
    UnifiedMetadata? base,
  ) {
    if (sources.isEmpty) return null;
    final targets = <String>[
      if (base != null) ...[
        base.title,
        if (base.englishTitle != null) base.englishTitle!,
        if (base.japaneseTitle != null) base.japaneseTitle!,
      ],
      query,
    ].map(_normalizeTitle).where((item) => item.isNotEmpty).toSet().toList();

    UnifiedSource? best;
    var bestScore = 0;
    for (final source in sources) {
      final title = _normalizeTitle(source.title);
      if (title.isEmpty) continue;
      for (final target in targets) {
        var score = 0;
        if (title == target) {
          score = 100;
        } else if (title.contains(target) || target.contains(title)) {
          score = 60;
        } else {
          final left = title.split(' ').toSet();
          final right = target.split(' ').toSet();
          score = left.intersection(right).length * 10;
        }
        if (score > bestScore) {
          bestScore = score;
          best = source;
        }
      }
    }
    if (bestScore <= 0) return null;
    return best;
  }

  int _sourcePriority(String providerId) {
    return switch (providerId) {
      'anilibria' => 0,
      'yani' => 1,
      'kodik' => 2,
      'hdrezka' => 3,
      'animevost' => 4,
      'sameband' => 5,
      'anilibme' => 6,
      _ => 9,
    };
  }

  /// Get full source details by provider and source ID.
  Future<UnifiedSource?> getSourceDetails(
    String providerId, String sourceId, {
    bool refresh = false,
  }) async {
    final provider = _registry.getSourceProvider(providerId);
    if (provider == null) return null;
    final cacheKey = CacheKeys.sourceDetails(providerId, sourceId);
    if (!refresh) {
      final cached = _cache.get<UnifiedSource>(cacheKey);
      if (cached != null) return cached;
    }
    UnifiedSource? result;
    try {
      result = await _withRetry<UnifiedSource?>(
        () => provider.getSource(sourceId),
        attempts: 2,
        timeout: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
    if (result != null) {
      _cache.set(cacheKey, result, ttl: _sourcesTtl);
    }
    return result;
  }

  // ============ unified anime with sources ============

  /// Get anime with all sources (Shikimori metadata + video sources).
  ///
  /// Paints a partial result as soon as base metadata is ready, then fills in
  /// enrichment, sources and related anime in parallel.
  Future<AnimeWithSources> getAnimeWithSources(
    int shikimoriId, {
    bool refresh = false,
    void Function(AnimeWithSources partial)? onPartial,
  }) async {
    final cacheKey = CacheKeys.animeWithSources(shikimoriId);
    if (!refresh) {
      final cached = _cache.get<AnimeWithSources>(cacheKey);
      if (cached != null) return cached;
    }

    // 1. Base Shikimori details first (fast UI paint).
    final baseDetails = await getBaseDetails(shikimoriId, refresh: refresh);
    if (baseDetails == null) {
      throw Exception('Anime not found: $shikimoriId');
    }

    onPartial?.call(AnimeWithSources(
      shikimoriAnime: _convertToShikimoriDetails(baseDetails),
      sources: const [],
      related: const [],
    ));

    // 2. Parallel load: enriched metadata + sources + related.
    final results = await Future.wait([
      getEnrichedMetadata(shikimoriId, refresh: refresh),
      findSourcesByShikimoriId(
        shikimoriId,
        refresh: refresh,
        nameHint: baseDetails.title,
      ),
      _loadRelated(baseDetails),
    ]);
    final enriched = results[0] as UnifiedMetadata;
    final sources = results[1] as List<UnifiedSource>;
    final related = results[2] as List<ShikimoriAnime>;

    // 3. Convert enriched metadata to legacy ShikimoriAnimeDetails for UI.
    final shikimoriDetails = _convertToShikimoriDetails(enriched);

    // 4. Build AnimeSource objects from UnifiedSources.
    final animeSources = _buildAnimeSources(shikimoriDetails, sources);

    // 5. Deduplicate by voiceover.
    final deduplicated = _deduplicateSources(animeSources);

    final result = AnimeWithSources(
      shikimoriAnime: shikimoriDetails,
      sources: deduplicated,
      related: related,
    );

    _cache.set(cacheKey, result, ttl: _animeWithSourcesTtl);
    return result;
  }

  Future<List<ShikimoriAnime>> _loadRelated(UnifiedMetadata base) async {
    final franchise = base.franchise;
    if (franchise == null || franchise.isEmpty) return const [];
    try {
      final items = await _withRetry(
        () => getRelatedByFranchise(franchise, limit: 30),
        timeout: const Duration(seconds: 5),
      );
      final filtered = items.where((anime) => anime.shikimoriId != base.shikimoriId).toList();
      filtered.sort((a, b) {
        final aYear = a.year ?? 9999;
        final bYear = b.year ?? 9999;
        return aYear.compareTo(bYear);
      });
      return filtered.map(_convertToShikimoriAnime).toList();
    } catch (_) {
      return const [];
    }
  }

  List<AnimeSource> _buildAnimeSources(
    ShikimoriAnimeDetails shikimori,
    List<UnifiedSource> sources,
  ) {
    final animeSources = <AnimeSource>[];

    for (final source in sources) {
      if (source.episodes.isEmpty) continue;

      final episodes = source.episodes
          .map(_convertEpisode)
          .toList()
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));

      final release = AnimeRelease(
        id: shikimori.id,
        alias: '',
        name: shikimori.displayTitle,
        englishName: shikimori.name,
        description: shikimori.descriptionText,
        year: shikimori.year,
        type: shikimori.kind,
        season: null,
        ageRating: shikimori.rating?.toUpperCase(),
        shikimoriRating: shikimori.scoreValue,
        internalRating: null,
        posterPath: shikimori.posterOriginalUrl ?? shikimori.metadataPoster,
        posterThumbPath: shikimori.posterUrl,
        backgroundPath: shikimori.backgroundUrl ?? shikimori.metadataBackground,
        isOngoing: shikimori.isOngoing,
        isInProduction: shikimori.status == 'anons',
        episodesTotal: episodes.length,
        genres: shikimori.allGenres,
        members: const [],
        episodes: episodes,
        publishDay: null,
        blockedByGeo: false,
        blockedByCopyrights: false,
        freshAt: null,
        notification: null,
        shikimoriId: shikimori.id,
      );

      final voiceover = GenericVoiceover(
        id: '${source.providerId}_${_stableId(source.title)}',
        title: source.title,
        subtitle: source.subtitle ?? '${source.providerId} · ${source.title}',
        source: source.providerId,
        logoUrl: source.logoUrl,
        episodeCount: episodes.length,
      );

      animeSources.add(AnimeSource(
        id: source.id,
        shikimoriAnime: shikimori,
        release: release,
        voiceover: voiceover,
        sourceType: source.providerId,
      ));
    }

    return animeSources;
  }

  List<AnimeSource> _deduplicateSources(List<AnimeSource> sources) {
    final seen = <String>{};
    final result = <AnimeSource>[];

    for (final source in sources) {
      // Include sourceType in key so voiceovers with same name from different
      // providers are both shown (e.g., "анидуб" from anilibria vs animevost).
      final key = '${source.sourceType}:${_normalizeTitle(source.voiceover.title)}';
      if (seen.add(key.isEmpty ? source.id : key)) {
        result.add(source);
      }
    }

    result.sort((a, b) {
      final byPriority =
          _sourcePriority(a.sourceType).compareTo(_sourcePriority(b.sourceType));
      if (byPriority != 0) return byPriority;
      return a.voiceover.title.compareTo(b.voiceover.title);
    });

    return result;
  }

  String _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.toLowerCase().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _normalizeTitle(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ============ stream resolution ============

  /// Resolve an episode stream URL via the injected resolver.
  Future<String?> resolveStream(AnimeEpisode episode, {String quality = 'auto'}) async {
    final stream = await resolveStreamDetailed(episode, quality: quality);
    return stream?.url;
  }

  /// Resolve an episode to a direct stream including playback headers.
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

    final cacheKey = CacheKeys.resolvedStreamDetail(
      episode.resolverSource!,
      episode.resolverId!,
      quality,
    );

    final cached = _cache.get<ResolvedStream>(cacheKey);
    if (cached != null) return cached;

    ResolvedStream? stream;
    if (_streamResolverDetailed != null) {
      try {
        stream = await _streamResolverDetailed(episode, quality: quality)
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        stream = null;
      }
    } else if (_streamResolver != null) {
      try {
        final url = await _streamResolver(episode, quality: quality)
            .timeout(const Duration(seconds: 20));
        if (url != null && url.isNotEmpty) {
          stream = ResolvedStream(
            url: url,
            headers: episode.streamHeaders,
            kind: StreamKind.fromUrl(url),
          );
        }
      } catch (_) {
        stream = null;
      }
    }

    if (stream != null && stream.isPlayable) {
      _cache.set(cacheKey, stream, ttl: const Duration(hours: 1));
      _cache.set(
        CacheKeys.resolvedStream(
          episode.resolverSource!,
          episode.resolverId!,
          quality,
        ),
        stream.url,
        ttl: const Duration(hours: 1),
      );
    }
    return stream;
  }

  // ============ legacy compatibility (AniLibria release flow) ============

  /// Get a single AniLibria release by its release id.
  Future<AnimeRelease> release(int id, {bool refresh = false}) async {
    final anilibria = _registry.getSourceProvider('anilibria');
    if (anilibria == null) {
      throw Exception('AniLibria source is disabled');
    }
    final source = await _withRetry(
      () => anilibria.getSource(id.toString()),
      attempts: 2,
      timeout: const Duration(seconds: 8),
    );
    if (source == null || source.episodes.isEmpty) {
      throw Exception('Release not found: $id');
    }
    return _animeReleaseFromSource(id, source);
  }

  /// Franchise releases for a release id (best-effort; sources do not expose
  /// a franchise endpoint, so this returns related anime by Shikimori when
  /// available, otherwise an empty list).
  Future<List<AnimeFranchise>> franchises(
    int releaseId, {
    bool refresh = false,
  }) async {
    // Source providers do not expose a franchise endpoint. Return empty so the
    // legacy flow degrades gracefully instead of failing.
    return const [];
  }

  AnimeRelease _animeReleaseFromSource(int id, UnifiedSource source) {
    final episodes = source.episodes
        .map((e) => AnimeEpisode(
              id: e.id,
              ordinal: e.ordinal,
              name: e.title,
              hls480: e.hls480,
              hls720: e.hls720,
              hls1080: e.hls1080,
              durationSeconds: e.duration,
              previewPath: e.posterUrl,
              openingStart: e.openingStart,
              openingStop: e.openingStop,
              endingStart: e.endingStart,
              endingStop: e.endingStop,
              sortOrder: e.ordinal,
              resolverSource: e.resolverSource,
              resolverId: e.resolverId,
              embedUrl: e.embedUrl,
              embedLabel: e.embedLabel,
              streamHeaders: e.streamHeaders,
            ))
        .toList()
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));

    return AnimeRelease(
      id: id,
      alias: '',
      name: source.title,
      englishName: source.title,
      description: '',
      year: null,
      type: null,
      season: null,
      ageRating: null,
      shikimoriRating: null,
      internalRating: null,
      posterPath: source.logoUrl,
      posterThumbPath: source.logoUrl,
      backgroundPath: null,
      isOngoing: false,
      isInProduction: false,
      episodesTotal: episodes.length,
      genres: const [],
      members: const [],
      episodes: episodes,
      publishDay: null,
      blockedByGeo: false,
      blockedByCopyrights: false,
      freshAt: null,
      notification: null,
      shikimoriId: null,
    );
  }

  // ============ legacy compatibility (stream resolution) ============

  /// Resolve an episode stream lazily for scraped sources.
  Future<String?> resolveEpisodeStream(
    AnimeEpisode episode, {
    String quality = 'auto',
  }) async {
    return resolveStream(episode, quality: quality);
  }

  // ============ legacy model conversion ============

  ShikimoriAnimeDetails _convertToShikimoriDetails(UnifiedMetadata m) {
    return ShikimoriAnimeDetails(
      id: m.shikimoriId > 0 ? m.shikimoriId : m.id,
      name: m.englishTitle ?? m.title,
      russian: m.title,
      kind: m.kind ?? 'tv',
      score: (m.score ?? 0).toString(),
      status: m.status ?? 'released',
      episodes: m.episodes ?? 0,
      episodesAired: m.episodes ?? 0,
      image: ShikimoriImage(
        original: m.posterUrl,
        preview: m.posterUrl,
        x96: null,
        x48: null,
      ),
      url: '',
      airedOn: null,
      releasedOn: null,
      duration: m.duration,
      description: m.description ?? '',
      descriptionHtml: m.description,
      rating: m.ageRating,
      english: m.englishTitle != null ? [m.englishTitle!] : null,
      japanese: m.japaneseTitle != null ? [m.japaneseTitle!] : null,
      synonyms: null,
      genres: m.genres.map((g) => ShikimoriGenre(id: g.hashCode, name: g, russian: g)).toList(),
      studios: m.studios.map((s) => ShikimoriStudio(id: s.hashCode, name: s)).toList(),
      videos: const [],
      trailerUrl: m.trailerUrl,
      trailerThumbnail: m.trailerThumbnail,
      trailerSite: m.trailerSite,
      screenshots: m.screenshots,
      franchise: m.franchise,
      metadataPoster: m.posterUrl,
      metadataBackground: m.backgroundUrl,
      metadataScore: m.score,
      metadataYear: m.year,
      metadataEpisodes: m.episodes,
      metadataDuration: m.duration,
      metadataDescription: m.description,
      metadataEnglishTitle: m.englishTitle,
      metadataGenres: m.genres,
      metadataStudios: m.studios,
      anilibriaPosterFallback: null,
      anilibriaBackgroundFallback: null,
    );
  }

  ShikimoriAnime _convertToShikimoriAnime(UnifiedMetadata m) {
    return ShikimoriAnime(
      id: m.shikimoriId > 0 ? m.shikimoriId : m.id,
      name: m.englishTitle ?? m.title,
      russian: m.title,
      kind: m.kind ?? 'tv',
      score: (m.score ?? 0).toString(),
      status: m.status ?? 'released',
      episodes: m.episodes ?? 0,
      episodesAired: m.episodes ?? 0,
      image: ShikimoriImage(
        original: m.posterUrl,
        preview: m.posterUrl,
        x96: null,
        x48: null,
      ),
      url: '',
      airedOn: m.year != null ? '${m.year}-01-01' : null,
      releasedOn: null,
    );
  }

  AnimeEpisode _convertEpisode(UnifiedEpisode e) {
    return AnimeEpisode(
      id: e.id,
      ordinal: e.ordinal,
      name: e.title,
      hls480: e.hls480,
      hls720: e.hls720,
      hls1080: e.hls1080,
      durationSeconds: e.duration,
      previewPath: e.posterUrl,
      openingStart: e.openingStart,
      openingStop: e.openingStop,
      endingStart: e.endingStart,
      endingStop: e.endingStop,
      sortOrder: e.ordinal,
      resolverSource: e.resolverSource,
      resolverId: e.resolverId,
      embedUrl: e.embedUrl,
      embedLabel: e.embedLabel,
      streamHeaders: e.streamHeaders,
    );
  }
}
