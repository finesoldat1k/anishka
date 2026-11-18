import 'dart:async';

import '../api/anilibria_api.dart';
import '../api/shikimori_api.dart';
import '../models/anime_episode.dart';
import '../models/anime_franchise.dart';
import '../models/anime_release.dart';
import '../models/anime_source.dart';
import '../models/shikimori_anime.dart';
import '../models/video_source.dart';
import '../models/voiceover.dart';
import '../sources/source_manager.dart';

/// Unified repository: Shikimori for catalog/search, multi-source for playback.
class AnimeRepository {
  AnimeRepository({
    AniLibriaApi? anilibriaApi,
    ShikimoriApi? shikimoriApi,
    VideoSourceManager? sourceManager,
  }) : _anilibriaApi = anilibriaApi ?? AniLibriaApi(),
       _shikimoriApi = shikimoriApi ?? ShikimoriApi(),
       _sourceManager = sourceManager ?? VideoSourceManager();

  final AniLibriaApi _anilibriaApi;
  final ShikimoriApi _shikimoriApi;
  final VideoSourceManager _sourceManager;

  // Shikimori cache
  static const _shikimoriListTtl = Duration(minutes: 10);
  static const _shikimoriSearchTtl = Duration(minutes: 5);
  static const _shikimoriDetailsTtl = Duration(minutes: 30);

  List<ShikimoriAnime>? _popularCache;
  DateTime? _popularCacheAt;
  final Map<String, List<ShikimoriAnime>> _shikimoriSearchCache = {};
  final Map<String, DateTime> _shikimoriSearchCacheAt = {};
  final Map<int, ShikimoriAnimeDetails> _shikimoriDetailsCache = {};
  final Map<int, DateTime> _shikimoriDetailsCacheAt = {};
  final Map<String, Future<List<ShikimoriAnime>>> _shikimoriSearchRequests = {};
  final Map<int, Future<ShikimoriAnimeDetails>> _shikimoriDetailsRequests = {};

  // AniLibria cache (existing)
  static const _releaseTtl = Duration(minutes: 20);
  static const _franchiseTtl = Duration(hours: 6);

  final Map<int, AnimeRelease> _releases = {};
  final Map<int, DateTime> _releasesAt = {};
  final Map<int, List<AnimeFranchise>> _franchises = {};
  final Map<int, DateTime> _franchisesAt = {};
  final Map<int, Future<AnimeRelease>> _releaseRequests = {};

  // Unified cache
  final Map<int, AnimeWithSources> _animeWithSourcesCache = {};
  final Map<int, DateTime> _animeWithSourcesCacheAt = {};
  static const _animeWithSourcesTtl = Duration(minutes: 15);
  final Map<int, Future<AnimeWithSources>> _animeWithSourcesRequests = {};

  // ===== Shikimori Catalog =====

  /// Get popular/ongoing anime for home page (from Shikimori).
  Future<List<ShikimoriAnime>> getPopular({
    bool refresh = false,
    int limit = 50,
    String order = 'popularity',
    String? status,
    String? kind,
  }) async {
    if (!refresh &&
        _popularCache != null &&
        _popularCacheAt != null &&
        DateTime.now().difference(_popularCacheAt!) < _shikimoriListTtl) {
      return _popularCache!;
    }
    final result = await _shikimoriApi.getPopular(
      limit: limit,
      order: order,
      status: status,
      kind: kind,
    );
    _popularCache = result;
    _popularCacheAt = DateTime.now();
    return result;
  }

  /// Search anime on Shikimori.
  Future<List<ShikimoriAnime>> searchShikimori(String query, {bool refresh = false}) async {
    final trimmed = query.trim();
    final key = trimmed.toLowerCase();
    if (key.isEmpty) return const [];
    if (!refresh &&
        _shikimoriSearchCache[key] != null &&
        _shikimoriSearchCacheAt[key] != null &&
        DateTime.now().difference(_shikimoriSearchCacheAt[key]!) < _shikimoriSearchTtl) {
      return _shikimoriSearchCache[key]!;
    }
    final pending = _shikimoriSearchRequests[key];
    if (pending != null && !refresh) return pending;

    final request = _shikimoriApi
        .search(query: trimmed, limit: 50)
        .then((items) {
          _shikimoriSearchCache[key] = items;
          _shikimoriSearchCacheAt[key] = DateTime.now();
          return items;
        })
        .whenComplete(() {
          _shikimoriSearchRequests.remove(key);
        });
    _shikimoriSearchRequests[key] = request;
    return request;
  }

  /// Get Shikimori anime details by ID.
  Future<ShikimoriAnimeDetails> getShikimoriDetails(int id, {bool refresh = false}) async {
    if (!refresh &&
        _shikimoriDetailsCache[id] != null &&
        _shikimoriDetailsCacheAt[id] != null &&
        DateTime.now().difference(_shikimoriDetailsCacheAt[id]!) < _shikimoriDetailsTtl) {
      return _shikimoriDetailsCache[id]!;
    }
    final pending = _shikimoriDetailsRequests[id];
    if (pending != null && !refresh) return pending;

    final request = _shikimoriApi
        .getDetails(id)
        .then((details) {
          _shikimoriDetailsCache[id] = details;
          _shikimoriDetailsCacheAt[id] = DateTime.now();
          return details;
        })
        .whenComplete(() {
          _shikimoriDetailsRequests.remove(id);
        });
    _shikimoriDetailsRequests[id] = request;
    return request;
  }

  // ===== AniLibria Sources =====

  Future<AnimeRelease> _getAnilibriaRelease(int id, {bool refresh = false}) async {
    if (!refresh &&
        _releases[id] != null &&
        _releasesAt[id] != null &&
        DateTime.now().difference(_releasesAt[id]!) < _releaseTtl) {
      return _releases[id]!;
    }
    final pending = _releaseRequests[id];
    if (pending != null && !refresh) return pending;

    final request = _anilibriaApi
        .release(id)
        .then((release) {
          _releases[id] = release;
          _releasesAt[id] = DateTime.now();
          return release;
        })
        .whenComplete(() {
          _releaseRequests.remove(id);
        });
    _releaseRequests[id] = request;
    return request;
  }

  // ===== Unified: Shikimori + Sources =====

  /// Get anime with all available sources (Shikimori details + AniLibria releases).
  Future<AnimeWithSources> getAnimeWithSources(int shikimoriId, {bool refresh = false}) async {
    if (!refresh &&
        _animeWithSourcesCache[shikimoriId] != null &&
        _animeWithSourcesCacheAt[shikimoriId] != null &&
        DateTime.now().difference(_animeWithSourcesCacheAt[shikimoriId]!) < _animeWithSourcesTtl) {
      return _animeWithSourcesCache[shikimoriId]!;
    }
    final pending = _animeWithSourcesRequests[shikimoriId];
    if (pending != null && !refresh) return pending;

    final request = _buildAnimeWithSources(shikimoriId)
        .then((animeWithSources) {
          _animeWithSourcesCache[shikimoriId] = animeWithSources;
          _animeWithSourcesCacheAt[shikimoriId] = DateTime.now();
          return animeWithSources;
        })
        .whenComplete(() {
          _animeWithSourcesRequests.remove(shikimoriId);
        });
    _animeWithSourcesRequests[shikimoriId] = request;
    return request;
  }

  Future<AnimeWithSources> _buildAnimeWithSources(int shikimoriId) async {
    // 1. Get Shikimori details
    final shikimoriDetails = await _shikimoriApi.getDetails(shikimoriId);

    // 2. Find AniLibria releases for this Shikimori ID
    final nameHint = shikimoriDetails.russian.isNotEmpty
        ? shikimoriDetails.russian
        : shikimoriDetails.name;

    final found = await _anilibriaApi.findByShikimoriId(shikimoriId, nameHint: nameHint);

    // The catalog search returns compact releases without members/episodes.
    // Load full details for every match (also warms the player cache).
    final releases = await Future.wait(
      found.map((release) async {
        try {
          return await _getAnilibriaRelease(release.id);
        } catch (_) {
          return release;
        }
      }),
    );

    // 3. Enrich Shikimori details with AniLibria poster fallback
    final enrichedShikimori = _enrichWithAnilibriaPosters(shikimoriDetails, releases);

    // 4. Build sources from releases (AniLibria)
    final sources = <AnimeSource>[];
    for (final release in releases) {
      final voiceActors = release.voiceActors;
      if (voiceActors.isEmpty) continue;

      for (final voice in voiceActors) {
        final source = AnimeSource(
          id: 'anilibria:${release.id}:${voice.nickname}',
          shikimoriAnime: enrichedShikimori,
          release: release,
          voiceover: AniLibriaVoiceover(voice),
          sourceType: 'anilibria',
        );
        sources.add(source);
      }
    }

    // 5. Search additional video sources (AnimeVost, AniDub, Kodik) by title
    final additionalSources = await _fetchAdditionalSources(shikimoriDetails, enrichedShikimori);
    sources.addAll(additionalSources);

    // 6. Fetch related anime from Shikimori franchise
    final related = <ShikimoriAnime>[];
    if (enrichedShikimori.franchise != null && enrichedShikimori.franchise!.isNotEmpty) {
      try {
        final franchiseAnime = await _shikimoriApi.getByFranchise(enrichedShikimori.franchise!, limit: 20);
        // Exclude current anime from related
        related.addAll(franchiseAnime.where((a) => a.id != shikimoriId));
      } catch (_) {
        // Ignore franchise fetch errors
      }
    }

    return AnimeWithSources(
      shikimoriAnime: enrichedShikimori,
      sources: sources,
      related: related,
    );
  }

  /// Search additional video sources (AnimeVost, AniDub, Kodik) for this anime.
  Future<List<AnimeSource>> _fetchAdditionalSources(
    ShikimoriAnimeDetails shikimori,
    ShikimoriAnimeDetails enrichedShikimori,
  ) async {
    final additionalSources = <AnimeSource>[];
    final searchTitle = shikimori.russian.isNotEmpty ? shikimori.russian : shikimori.name;

    // Search all video sources in parallel, but never block the details page
    // for too long if a scraper is slow or unreachable.
    List<SourceAnimeEntry> results;
    try {
      results = await _sourceManager
          .search(searchTitle, limit: 10)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      results = const [];
    }

    // Group results by source
    final bySource = <String, List<SourceAnimeEntry>>{};
    for (final entry in results) {
      if (entry.sourceId == 'anilibria') continue; // already handled above
      bySource.putIfAbsent(entry.sourceId, () => []).add(entry);
    }

    // Convert to AnimeSource objects
    for (final entry in bySource.entries) {
      final sourceId = entry.key;
      final entries = entry.value;
      if (entries.isEmpty) continue;

      // Use the first match from each source
      final match = entries.first;
      SourceAnimeDetails? details;
      try {
        details = await _sourceManager
            .getDetails(sourceId, match.externalId)
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        details = null;
      }
      if (details == null) continue;
      final resolved = details;

      // Map voiceovers from this source
      final voiceovers = resolved.episodesList.isNotEmpty
          ? resolved.episodesList.take(1).map((e) => _createVoiceoverFromSource(sourceId, resolved)).toList()
          : <VoiceoverInfo>[];

      if (voiceovers.isEmpty) continue;

      for (final voice in voiceovers) {
        additionalSources.add(AnimeSource(
          id: '$sourceId:${match.externalId}:${voice.id}',
          shikimoriAnime: enrichedShikimori,
          release: _createReleaseFromSource(sourceId, resolved),
          voiceover: voice,
          sourceType: sourceId,
        ));
      }
    }

    return additionalSources;
  }

  VoiceoverInfo _createVoiceoverFromSource(String sourceId, SourceAnimeDetails details) {
    final sourceName = switch (sourceId) {
      'animevost' => 'AnimeVost',
      'anidub' => 'AniDub',
      'kodik' => 'Kodik',
      _ => sourceId,
    };
    return GenericVoiceover(
      id: '${sourceId}_default',
      title: sourceName,
      subtitle: '$sourceName · ${details.russianTitle ?? details.title}',
      source: sourceId,
    );
  }

  AnimeRelease _createReleaseFromSource(String sourceId, SourceAnimeDetails details) {
    return AnimeRelease(
      id: 0, // placeholder
      alias: '',
      name: details.russianTitle ?? details.title,
      englishName: details.title,
      description: details.description,
      year: details.year,
      type: details.kind,
      season: null,
      ageRating: null, // SourceAnimeDetails doesn't have rating
      shikimoriRating: double.tryParse(details.score ?? ''),
      internalRating: null,
      posterPath: details.posterUrl,
      posterThumbPath: details.posterUrl,
      backgroundPath: details.backgroundUrl,
      isOngoing: details.status == 'ongoing',
      isInProduction: details.status == 'anons',
      episodesTotal: details.episodes,
      genres: details.genres ?? [],
      members: [],
      episodes: details.episodesList
          .map((e) => AnimeEpisode(
                id: e.externalId,
                ordinal: e.ordinal,
                name: e.title ?? 'Серия ${e.ordinal}',
                hls480: e.hlsUrls['480'] ?? e.mp4Urls['480'] ?? e.hlsUrls['auto'] ?? e.mp4Urls['auto'],
                hls720: e.hlsUrls['720'] ?? e.mp4Urls['720'],
                hls1080: e.hlsUrls['1080'] ?? e.mp4Urls['1080'],
                durationSeconds: e.duration,
                previewPath: e.posterUrl,
                openingStart: null,
                openingStop: null,
                endingStart: null,
                endingStop: null,
                sortOrder: e.ordinal,
              ))
          .toList(),
      publishDay: null,
      blockedByGeo: false,
      blockedByCopyrights: false,
      freshAt: null,
      notification: null,
      shikimoriId: null,
    );
  }

  /// Enrich Shikimori details with AniLibria poster/background fallback.
  ShikimoriAnimeDetails _enrichWithAnilibriaPosters(
    ShikimoriAnimeDetails shikimori,
    List<AnimeRelease> releases,
  ) {
    if (releases.isEmpty) return shikimori;

    // Find the first release with a valid poster
    String? anilibriaPoster;
    String? anilibriaBackground;
    for (final r in releases) {
      if (anilibriaPoster == null && r.posterUrl != null && r.posterUrl!.isNotEmpty) {
        anilibriaPoster = r.posterUrl;
      }
      if (anilibriaBackground == null && r.backgroundUrl != null && r.backgroundUrl!.isNotEmpty) {
        anilibriaBackground = r.backgroundUrl;
      }
      if (anilibriaPoster != null && anilibriaBackground != null) break;
    }

    // Return enriched copy with fallbacks
    return shikimori.copyWith(
      anilibriaPosterFallback: anilibriaPoster,
      anilibriaBackgroundFallback: anilibriaBackground,
    );
  }

  // ===== Legacy compatibility =====

  Future<AnimeRelease> release(int id, {bool refresh = false}) => _getAnilibriaRelease(id, refresh: refresh);

  Future<List<AnimeFranchise>> franchises(int releaseId, {bool refresh = false}) {
    if (!refresh &&
        _franchises[releaseId] != null &&
        _franchisesAt[releaseId] != null &&
        DateTime.now().difference(_franchisesAt[releaseId]!) < _franchiseTtl) {
      return Future.value(_franchises[releaseId]!);
    }
    return _anilibriaApi.franchises(releaseId).then((items) {
      _franchises[releaseId] = items;
      _franchisesAt[releaseId] = DateTime.now();
      return items;
    });
  }

  AnimeRelease? cachedRelease(int id) => _releases[id];

  void clearCaches() {
    _popularCache = null;
    _popularCacheAt = null;
    _shikimoriSearchCache.clear();
    _shikimoriSearchCacheAt.clear();
    _shikimoriDetailsCache.clear();
    _shikimoriDetailsCacheAt.clear();
    _shikimoriSearchRequests.clear();
    _shikimoriDetailsRequests.clear();

    _releases.clear();
    _releasesAt.clear();
    _franchises.clear();
    _franchisesAt.clear();
    _releaseRequests.clear();

    _animeWithSourcesCache.clear();
    _animeWithSourcesCacheAt.clear();
    _animeWithSourcesRequests.clear();
  }
}
