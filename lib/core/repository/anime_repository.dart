import 'dart:async';
import 'dart:math' as math;

import '../api/anilibria_api.dart';
import '../api/anilist_api.dart';
import '../api/jikan_api.dart';
import '../api/kitsu_api.dart';
import '../api/shikimori_api.dart';
import '../api/yani_api.dart';
import '../models/anime_episode.dart';
import '../models/anime_franchise.dart';
import '../models/anime_release.dart';
import '../models/anime_source.dart';
import '../models/jikan_models.dart';
import '../models/shikimori_anime.dart';
import '../models/video_source.dart';
import '../models/voiceover.dart';
import '../sources/kodik_source.dart';
import '../sources/source_manager.dart';

/// Unified repository: Shikimori for catalog/search, multi-source for playback.
class AnimeRepository {
  AnimeRepository({
    AniLibriaApi? anilibriaApi,
    ShikimoriApi? shikimoriApi,
    AniListApi? anilistApi,
    KitsuApi? kitsuApi,
    JikanApi? jikanApi,
    VideoSourceManager? sourceManager,
    YaniApi? yaniApi,
  }) : _anilibriaApi = anilibriaApi ?? AniLibriaApi(),
       _shikimoriApi = shikimoriApi ?? ShikimoriApi(),
       _anilistApi = anilistApi ?? AniListApi(),
       _kitsuApi = kitsuApi ?? KitsuApi(),
       _jikanApi = jikanApi ?? JikanApi(),
       _yaniApi = yaniApi ?? YaniApi(),
       _sourceManager = sourceManager ?? _defaultSourceManager();

  static VideoSourceManager _defaultSourceManager() {
    const token = String.fromEnvironment('KODIK_TOKEN');
    final value = token.trim();
    return VideoSourceManager(
      kodik: value.isEmpty ? null : KodikVideoSource(token: value),
    );
  }

  final AniLibriaApi _anilibriaApi;
  final ShikimoriApi _shikimoriApi;
  final AniListApi _anilistApi;
  final KitsuApi _kitsuApi;
  final JikanApi _jikanApi;
  final YaniApi _yaniApi;
  final VideoSourceManager _sourceManager;

  // Shikimori cache
  static const _shikimoriListTtl = Duration(minutes: 10);
  static const _shikimoriSearchTtl = Duration(minutes: 5);
  static const _shikimoriDetailsTtl = Duration(minutes: 30);

  final Map<String, List<ShikimoriAnime>> _popularCache = {};
  final Map<String, DateTime> _popularCacheAt = {};
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

  // Enriched Shikimori details (metadata, trailer, stills) without sources.
  // The details page renders the base Shikimori response first and swaps in
  // this enriched copy as soon as it is ready.
  static const _animeMetadataTtl = Duration(minutes: 15);
  final Map<int, _AnimeMetadata> _animeMetadataCache = {};
  final Map<int, DateTime> _animeMetadataCacheAt = {};
  final Map<int, Future<_AnimeMetadata>> _animeMetadataRequests = {};

  // Unified cache
  final Map<int, AnimeWithSources> _animeWithSourcesCache = {};
  final Map<int, DateTime> _animeWithSourcesCacheAt = {};
  static const _animeWithSourcesTtl = Duration(minutes: 15);
  final Map<int, Future<AnimeWithSources>> _animeWithSourcesRequests = {};

  // Lazily resolved streams for scraped sources (AnimeVost, AniDub, ...).
  final Map<String, String> _resolvedStreams = {};

  // ===== Shikimori Catalog =====

  /// Get popular/ongoing anime for home page (from Shikimori).
  Future<List<ShikimoriAnime>> getPopular({
    bool refresh = false,
    int limit = 50,
    String order = 'popularity',
    String? status,
    String? kind,
  }) async {
    final cacheKey = '$order|${status ?? ''}|${kind ?? ''}|$limit';
    final cachedAt = _popularCacheAt[cacheKey];
    if (!refresh &&
        _popularCache[cacheKey] != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _shikimoriListTtl) {
      return _popularCache[cacheKey]!;
    }
    final result = await _shikimoriApi.getPopular(
      limit: limit,
      order: order,
      status: status,
      kind: kind,
    );
    _popularCache[cacheKey] = result;
    _popularCacheAt[cacheKey] = DateTime.now();
    return result;
  }

  /// Search anime on Shikimori.
  Future<List<ShikimoriAnime>> searchShikimori(
    String query, {
    bool refresh = false,
  }) async {
    final trimmed = query.trim();
    final key = trimmed.toLowerCase();
    if (key.isEmpty) return const [];
    if (!refresh &&
        _shikimoriSearchCache[key] != null &&
        _shikimoriSearchCacheAt[key] != null &&
        DateTime.now().difference(_shikimoriSearchCacheAt[key]!) <
            _shikimoriSearchTtl) {
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
  Future<ShikimoriAnimeDetails> getShikimoriDetails(
    int id, {
    bool refresh = false,
  }) async {
    if (!refresh &&
        _shikimoriDetailsCache[id] != null &&
        _shikimoriDetailsCacheAt[id] != null &&
        DateTime.now().difference(_shikimoriDetailsCacheAt[id]!) <
            _shikimoriDetailsTtl) {
      return _shikimoriDetailsCache[id]!;
    }
    final pending = _shikimoriDetailsRequests[id];
    if (pending != null) return pending;

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

  Future<AnimeRelease> _getAnilibriaRelease(
    int id, {
    bool refresh = false,
  }) async {
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

  /// Enriched Shikimori details without building playback sources.
  ///
  /// This is the fast layer used by the details page: the hero, synopsis,
  /// genres, studios and stills can be shown without waiting for AniLibria or
  /// the scrapers. [getAnimeWithSources] reuses the same cached metadata.
  Future<ShikimoriAnimeDetails> getAnimeDetails(
    int shikimoriId, {
    bool refresh = false,
  }) async {
    if (!refresh && _isMetadataFresh(shikimoriId)) {
      return _animeMetadataCache[shikimoriId]!.details;
    }
    final base = await getShikimoriDetails(shikimoriId, refresh: refresh);
    final metadata = await _loadMetadata(shikimoriId, base, refresh: refresh);
    return metadata.details;
  }

  /// Last fully loaded result, if it is still fresh.
  AnimeWithSources? cachedAnimeWithSources(int shikimoriId) {
    final cachedAt = _animeWithSourcesCacheAt[shikimoriId];
    final cached = _animeWithSourcesCache[shikimoriId];
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) >= _animeWithSourcesTtl) {
      return null;
    }
    return cached;
  }

  bool _isMetadataFresh(int shikimoriId) {
    final cachedAt = _animeMetadataCacheAt[shikimoriId];
    return _animeMetadataCache[shikimoriId] != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _animeMetadataTtl;
  }

  Future<_AnimeMetadata> _loadMetadata(
    int shikimoriId,
    ShikimoriAnimeDetails base, {
    bool refresh = false,
  }) {
    if (!refresh && _isMetadataFresh(shikimoriId)) {
      return Future.value(_animeMetadataCache[shikimoriId]);
    }
    final pending = _animeMetadataRequests[shikimoriId];
    if (pending != null) return pending;

    final request = _buildMetadata(shikimoriId, base)
        .then((metadata) {
          _animeMetadataCache[shikimoriId] = metadata;
          _animeMetadataCacheAt[shikimoriId] = DateTime.now();
          return metadata;
        })
        .whenComplete(() {
          _animeMetadataRequests.remove(shikimoriId);
        });
    _animeMetadataRequests[shikimoriId] = request;
    return request;
  }

  Future<_AnimeMetadata> _buildMetadata(
    int shikimoriId,
    ShikimoriAnimeDetails base,
  ) async {
    final anilistFuture = _findAniList(base);
    final kitsuFuture = _findKitsu(base);
    final jikanFuture = _findJikan(base);
    final screenshotsFuture = _safeScreenshots(shikimoriId);
    final yaniFuture = _loadYani(base);

    final anilist = await anilistFuture;
    final kitsu = await kitsuFuture;
    final jikan = await jikanFuture;
    final screenshots = await screenshotsFuture;
    final yani = await yaniFuture;

    return _AnimeMetadata(
      details: _enrichWithMetadata(
        base,
        anilist: anilist,
        kitsu: kitsu,
        jikan: jikan,
        screenshots: screenshots,
        yani: yani,
      ),
      yani: yani,
    );
  }

  /// Get anime with all available sources (Shikimori details + AniLibria releases).
  Future<AnimeWithSources> getAnimeWithSources(
    int shikimoriId, {
    bool refresh = false,
    void Function(AnimeWithSources partial)? onPartial,
  }) async {
    if (!refresh &&
        _animeWithSourcesCache[shikimoriId] != null &&
        _animeWithSourcesCacheAt[shikimoriId] != null &&
        DateTime.now().difference(_animeWithSourcesCacheAt[shikimoriId]!) <
            _animeWithSourcesTtl) {
      return _animeWithSourcesCache[shikimoriId]!;
    }
    final pending = _animeWithSourcesRequests[shikimoriId];
    if (pending != null) return pending;

    final request = _buildAnimeWithSources(shikimoriId, onPartial: onPartial)
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

  Future<AnimeWithSources> _buildAnimeWithSources(
    int shikimoriId, {
    void Function(AnimeWithSources partial)? onPartial,
  }) async {
    // 1. Base Shikimori details are the only blocking request.
    final shikimoriDetails = await getShikimoriDetails(shikimoriId);
    final nameHint = shikimoriDetails.russian.isNotEmpty
        ? shikimoriDetails.russian
        : shikimoriDetails.name;

    // The caller may render the hero with this partial result while sources
    // and metadata are still loading.
    onPartial?.call(
      AnimeWithSources(
        shikimoriAnime: shikimoriDetails,
        sources: const [],
        related: const [],
      ),
    );

    // 2. Kick off every independent request immediately. None of them is
    // allowed to block another one: a dead scraper must never hide the page.
    final releasesFuture = _loadAnilibriaReleases(shikimoriId, nameHint);
    final additionalFuture = _fetchAdditionalSources(shikimoriDetails);
    final relatedFuture = _loadRelated(shikimoriDetails);
    final metadataFuture = _loadMetadata(shikimoriId, shikimoriDetails);

    final releases = await releasesFuture;
    final metadata = await metadataFuture;
    final yani = metadata.yani;

    // 3. AniLibria poster fallback on top of the enriched metadata.
    final enrichedShikimori = _enrichWithAnilibriaPosters(
      metadata.details,
      releases,
    );

    // 4. Build one studio voiceover per AniLibria release (cast is secondary).
    final sources = <AnimeSource>[];
    final seenVoices = <String>{};
    void addSource(AnimeSource source) {
      final key = _normalizeTitle(source.voiceover.title);
      if (!seenVoices.add(key.isEmpty ? source.id : key)) return;
      sources.add(source);
    }

    for (final release in releases) {
      final members = release.voiceActors.isNotEmpty
          ? release.voiceActors
          : release.members;
      addSource(
        AnimeSource(
          id: 'anilibria:${release.id}',
          shikimoriAnime: enrichedShikimori,
          release: release,
          voiceover: AniLibriaVoiceover(
            releaseId: release.id,
            members: members,
            episodes: release.episodes.length,
          ),
          sourceType: 'anilibria',
        ),
      );
    }

    // 5. Additional video sources (AnimeVost, AniDub, optional Kodik).
    // They were requested with the base Shikimori details for speed, so swap
    // in the enriched metadata once AniList/Kitsu/screenshots have arrived.
    final additional = await additionalFuture;
    for (final source in additional) {
      addSource(
        AnimeSource(
          id: source.id,
          shikimoriAnime: enrichedShikimori,
          release: source.release,
          voiceover: source.voiceover,
          sourceType: source.sourceType,
        ),
      );
    }

    // 6. YummyAnime studio tracks (the broadest real voiceover catalogue).
    // They fill in every studio that the scrapers could not reach, including
    // JAM CLUB, SHIZA Project, AniStar, StudioBand, КОМНАТА ДИДИ and others.
    final yaniTracks = yani?.tracks ?? const <YaniTrack>[];
    for (final track in yaniTracks) {
      if (track.episodes.isEmpty) continue;
      final release = _createReleaseFromYani(enrichedShikimori, track);
      final voiceId = _yaniVoiceId(enrichedShikimori.id, track.studio);
      addSource(
        AnimeSource(
          id: 'yani:${enrichedShikimori.id}:$voiceId',
          shikimoriAnime: enrichedShikimori,
          release: release,
          voiceover: GenericVoiceover(
            id: voiceId,
            title: track.studio,
            subtitle: 'yani · ${track.players.join(', ')}',
            source: 'yani',
            logoUrl: _yaniStudioLogo(track.studio),
            participants: track.players,
            episodeCount: track.episodes.length,
          ),
          sourceType: 'yani',
        ),
      );
    }

    // 7. Related anime from the Shikimori franchise.
    final related = await relatedFuture;

    return AnimeWithSources(
      shikimoriAnime: enrichedShikimori,
      sources: sources,
      related: related,
    );
  }

  Future<List<AnimeRelease>> _loadAnilibriaReleases(
    int shikimoriId,
    String nameHint,
  ) async {
    try {
      final found = await _anilibriaApi
          .findByShikimoriId(shikimoriId, nameHint: nameHint)
          .timeout(const Duration(seconds: 8));
      if (found.isEmpty) return const [];

      // The catalog search returns compact releases without members/episodes.
      // Load full details for every match (also warms the player cache).
      final loaded = await Future.wait(
        found.map((release) async {
          try {
            return await _getAnilibriaRelease(release.id)
                .timeout(const Duration(seconds: 7));
          } catch (_) {
            return release;
          }
        }),
      );
      return loaded;
    } catch (_) {
      return const [];
    }
  }

  Future<List<ShikimoriAnime>> _loadRelated(
    ShikimoriAnimeDetails details,
  ) async {
    final franchise = details.franchise;
    if (franchise == null || franchise.isEmpty) return const [];
    try {
      final items = await _shikimoriApi
          .getByFranchise(franchise, limit: 30)
          .timeout(const Duration(seconds: 5));
      final filtered = items.where((anime) => anime.id != details.id).toList();
      // Sort by release date (airedOn) from oldest to newest
      filtered.sort((a, b) {
        final aDate = a.airedOn;
        final bDate = b.airedOn;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      return filtered;
    } catch (_) {
      return const [];
    }
  }

  // ===== Metadata enrichment =====

  List<String> _searchQueries(ShikimoriAnimeDetails details) {
    final queries = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return;
      if (queries.any((q) => q.toLowerCase() == text.toLowerCase())) return;
      queries.add(text);
    }

    add(details.russian);
    add(details.name);
    if (details.english != null) {
      for (final value in details.english!) {
        add(value);
      }
    }
    if (details.synonyms != null) {
      for (final value in details.synonyms!.take(2)) {
        add(value);
      }
    }
    return queries.take(2).toList();
  }

  Future<AniListMedia?> _findAniList(ShikimoriAnimeDetails details) async {
    for (final query in _searchQueries(details)) {
      try {
        final media = await _anilistApi
            .find(query)
            .timeout(const Duration(seconds: 4));
        if (media != null) return media;
      } catch (_) {
        // Try the next title variant.
      }
    }
    return null;
  }

  Future<KitsuMedia?> _findKitsu(ShikimoriAnimeDetails details) async {
    for (final query in _searchQueries(details)) {
      try {
        final media = await _kitsuApi
            .find(query)
            .timeout(const Duration(seconds: 4));
        if (media != null) return media;
      } catch (_) {
        // Try the next title variant.
      }
    }
    return null;
  }

  Future<JikanAnimeDetails?> _findJikan(ShikimoriAnimeDetails details) async {
    for (final query in _searchQueries(details)) {
      try {
        final media = await _jikanApi
            .findByTitle(query)
            .timeout(const Duration(seconds: 6));
        if (media != null) return media;
      } catch (_) {
        // Try the next title variant.
      }
    }
    return null;
  }

  Future<List<String>> _safeScreenshots(int id) async {
    try {
      return await _shikimoriApi
          .screenshots(id)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return const [];
    }
  }

  /// Load real voiceover studios and screenshots from YummyAnime.
  ///
  /// This is best-effort: the details page must open even when the API is
  /// unreachable, so every failure collapses to `null`.
  Future<YaniBundle?> _loadYani(ShikimoriAnimeDetails details) async {
    final queries = <String>{
      ..._searchQueries(details),
      details.russian,
      details.name,
    }.map((query) => query.trim()).where((query) => query.isNotEmpty).toList();
    if (queries.isEmpty) return null;
    try {
      return await _yaniApi
          .findBundle(details.id, queries: queries.take(2).toList())
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  ShikimoriAnimeDetails _enrichWithMetadata(
    ShikimoriAnimeDetails details, {
    required AniListMedia? anilist,
    required KitsuMedia? kitsu,
    required JikanAnimeDetails? jikan,
    required List<String> screenshots,
    required YaniBundle? yani,
  }) {
    String? shikimoriTrailer;
    for (final video in details.videos ?? const <ShikimoriVideo>[]) {
      if (video.url.trim().isEmpty) continue;
      if (video.kind != 'pv' && video.kind != 'op') continue;
      shikimoriTrailer = video.url;
      break;
    }

    final kitsuTrailer = kitsu?.youtubeVideoId?.trim();
    final trailerUrl =
        shikimoriTrailer ??
        anilist?.trailerUrl ??
        (kitsuTrailer == null || kitsuTrailer.isEmpty
            ? null
            : 'https://www.youtube.com/watch?v=$kitsuTrailer');

    final trailerThumbnail =
        anilist?.trailerThumbnail ??
        (trailerUrl == null ? null : _youtubeThumbnail(trailerUrl));

    final yaniPoster = yani?.details?.posterUrl ?? yani?.anime.posterUrl;

    final mergedScreenshots = <String>{...screenshots};
    for (final shot in yani?.details?.screenshots ?? const <YaniScreenshot>[]) {
      if (shot.url.isNotEmpty) mergedScreenshots.add(shot.url);
    }

    return details.copyWith(
      screenshots: mergedScreenshots.toList(),
      trailerUrl: trailerUrl,
      trailerThumbnail: trailerThumbnail,
      trailerSite:
          anilist?.trailerSite ??
          (trailerUrl?.contains('youtu') == true ? 'youtube' : null),
      metadataPoster:
          anilist?.posterUrl ?? kitsu?.posterUrl ?? jikan?.posterUrl ?? yaniPoster,
      metadataBackground:
          anilist?.bannerUrl ??
          kitsu?.coverUrl ??
          jikan?.backgroundUrl ??
          yani?.details?.backgroundUrl ??
          yaniPoster,
      metadataScore: anilist?.score ?? kitsu?.score ?? jikan?.score,
      metadataYear: anilist?.year ?? kitsu?.year ?? jikan?.year,
      metadataEpisodes: anilist?.episodes ?? kitsu?.episodes ?? jikan?.episodeCount,
      metadataDuration: anilist?.duration ?? kitsu?.episodeLength,
      metadataDescription: _preferredDescription(
        anilist?.description,
        kitsu?.synopsis,
        jikan?.synopsis,
      ),
      metadataEnglishTitle:
          anilist?.english ?? kitsu?.englishTitle ?? jikan?.titleEnglish,
      metadataGenres: anilist?.genres ?? jikan?.allGenres ?? const [],
      metadataStudios: anilist?.studios ?? jikan?.allStudios ?? const [],
    );
  }

  String? _preferredDescription(String? anilist, String? kitsu, String? jikan) {
    final primary = anilist?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final secondary = kitsu?.trim();
    if (secondary != null && secondary.isNotEmpty) return secondary;
    final tertiary = jikan?.trim();
    if (tertiary != null && tertiary.isNotEmpty) return tertiary;
    return null;
  }

  String? _youtubeThumbnail(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    String? id;
    if (host.contains('youtu.be')) {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host.contains('youtu')) {
      id = uri.queryParameters['v'];
      if (id == null && uri.pathSegments.length >= 2) {
        id = uri.pathSegments[1];
      }
    }
    if (id == null || id.isEmpty) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  // ===== Additional video sources =====

  /// Search additional video sources (AnimeVost, AniDub, Kodik) for this anime.
  ///
  /// Kodik returns one entry per translation track, so a single title can
  /// produce many voiceovers: `AniStar`, `JAM CLUB`, `SHIZA Project`,
  /// `КОМНАТА ДИДИ`, `AniBaza`, `StudioBand`, ... They all become separate
  /// [AnimeSource] objects and are listed on the voiceover page.
  Future<List<AnimeSource>> _fetchAdditionalSources(
    ShikimoriAnimeDetails shikimori,
  ) async {
    final query = shikimori.russian.isNotEmpty
        ? shikimori.russian
        : shikimori.name;
    if (query.trim().isEmpty) return const [];

    // Search all video sources in parallel, but never block the details page
    // for too long if a scraper is slow or unreachable.
    final results = <SourceAnimeEntry>[];
    final seen = <String>{};
    try {
      final entries = await _sourceManager
          .search(query, limit: 20)
          .timeout(const Duration(seconds: 5));
      for (final entry in entries) {
        if (entry.sourceId == 'anilibria') continue; // handled above
        if (seen.add('${entry.sourceId}:${entry.externalId}')) {
          results.add(entry);
        }
      }
    } catch (_) {
      return const [];
    }

    // Group results by source and pick the best title/year match only.
    final bySource = <String, List<SourceAnimeEntry>>{};
    for (final entry in results) {
      bySource.putIfAbsent(entry.sourceId, () => []).add(entry);
    }

    final matches = <String, SourceAnimeEntry>{};
    for (final entry in bySource.entries) {
      final match = _bestMatch(entry.value, shikimori);
      if (match != null) matches[entry.key] = match;
    }
    if (matches.isEmpty) return const [];

    // Details for every matched source load in parallel.
    final detailsBySource = <String, SourceAnimeDetails>{};
    await Future.wait(
      matches.entries.map((entry) async {
        try {
          final details = await _sourceManager
              .getDetails(entry.key, entry.value.externalId)
              .timeout(const Duration(seconds: 4));
          if (details != null) detailsBySource[entry.key] = details;
        } catch (_) {
          // A broken scraper must not hide the other sources.
        }
      }),
    );

    final additionalSources = <AnimeSource>[];
    for (final entry in matches.entries) {
      final sourceId = entry.key;
      final details = detailsBySource[sourceId];
      if (details == null) continue;
      final match = entry.value;

      for (final voice in _voiceTracksFor(sourceId, details)) {
        if (voice.episodes.isEmpty) continue;
        final release = _createReleaseFromSource(
          sourceId,
          details,
          libraryId: shikimori.id,
          episodes: voice.episodes,
        );
        additionalSources.add(
          AnimeSource(
            id: '$sourceId:${match.externalId}:${voice.key}',
            shikimoriAnime: shikimori,
            release: release,
            voiceover: GenericVoiceover(
              id: '${sourceId}_${voice.key}',
              title: voice.title,
              subtitle: voice.subtitle,
              source: sourceId,
              logoUrl: voice.logoUrl,
              episodeCount: voice.episodes.length,
            ),
            sourceType: sourceId,
          ),
        );
      }
    }

    additionalSources.sort((a, b) {
      final bySource = _sourcePriority(a.sourceType)
          .compareTo(_sourcePriority(b.sourceType));
      if (bySource != 0) return bySource;
      return a.voiceover.title.compareTo(b.voiceover.title);
    });
    return additionalSources;
  }

  /// Split source details into separate voiceover tracks.
  ///
  /// Kodik lists episodes for every translation it has. Other scrapers return
  /// a single track, so they collapse into one entry.
  List<_VoiceTrack> _voiceTracksFor(
    String sourceId,
    SourceAnimeDetails details,
  ) {
    final groups = <String, List<SourceEpisode>>{};
    final titles = <String, String>{};
    for (final episode in details.episodesList) {
      final id = (episode.voiceId ?? '').trim();
      final key = id.isEmpty ? 'default' : id;
      groups.putIfAbsent(key, () => []).add(episode);
      final title = (episode.voiceTitle ?? '').trim();
      if (title.isNotEmpty) titles[key] = title;
    }

    if (groups.isEmpty) return const [];
    final sourceLabel = _sourceLabel(sourceId);
    final tracks = <_VoiceTrack>[];
    for (final entry in groups.entries) {
      final rawTitle = titles[entry.key] ?? '';
      final title = rawTitle.isEmpty ? sourceLabel : rawTitle;
      final isStudioName =
          _normalizeTitle(title) != _normalizeTitle(sourceLabel);
      tracks.add(
        _VoiceTrack(
          key: entry.key,
          title: title,
          subtitle: isStudioName
              ? 'озвучка студии · $sourceLabel'
              : 'озвучка студии · $sourceLabel',
          logoUrl: _sourceLogo(sourceId, title),
          episodes: entry.value,
        ),
      );
    }
    return tracks;
  }

  String _sourceLabel(String sourceId) => switch (sourceId) {
    'anilibria' => 'anilibria',
    'animevost' => 'animevost',
    'anidub' => 'anidub',
    'kodik' => 'kodik',
    _ => sourceId,
  };

  String? _sourceLogo(String sourceId, String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('anilibria')) {
      return 'https://anilibria.top/favicon.ico';
    }
    return switch (sourceId) {
      'anilibria' => 'https://anilibria.top/favicon.ico',
      'animevost' => 'https://animevost.org/favicon.ico',
      'anidub' => 'https://anidub.com/favicon.ico',
      _ => null,
    };
  }

  int _sourcePriority(String sourceId) => switch (sourceId) {
    'anilibria' => 0,
    'animevost' => 1,
    'anidub' => 2,
    'kodik' => 3,
    _ => 9,
  };

  SourceAnimeEntry? _bestMatch(
    List<SourceAnimeEntry> entries,
    ShikimoriAnimeDetails anime,
  ) {
    final targets = <String>{
      _normalizeTitle(anime.russian),
      _normalizeTitle(anime.name),
      if (anime.english != null)
        for (final value in anime.english!) _normalizeTitle(value),
      if (anime.synonyms != null)
        for (final value in anime.synonyms!.take(2)) _normalizeTitle(value),
    }..removeWhere((value) => value.isEmpty);
    if (targets.isEmpty) return null;

    final year = anime.year;
    SourceAnimeEntry? best;
    var bestScore = 0;

    for (final entry in entries) {
      final names = <String>{
        _normalizeTitle(entry.displayTitle),
        _normalizeTitle(entry.title),
        if (entry.russianTitle != null) _normalizeTitle(entry.russianTitle!),
      }..removeWhere((value) => value.isEmpty);

      var score = 0;
      for (final name in names) {
        for (final target in targets) {
          if (name == target) {
            score = math.max(score, 8);
          } else if (name.contains(target) || target.contains(name)) {
            score = math.max(score, 4);
          }
        }
      }
      if (score == 0) continue;

      if (year != null && entry.year != null) {
        final diff = (entry.year! - year).abs();
        if (diff == 0) {
          score += 4;
        } else if (diff <= 1) {
          score += 1;
        } else {
          score -= 2;
        }
      }
      if (entry.kind != null && anime.kind.isNotEmpty) {
        final targetKind = _normalizeKind(anime.kind);
        final entryKind = _normalizeKind(entry.kind!);
        if (targetKind.isNotEmpty && targetKind == entryKind) score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }

    // Avoid obvious mismatches: require at least a partial title match.
    return bestScore >= 4 ? best : null;
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

  String _normalizeKind(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('фильм') || normalized.contains('movie')) {
      return 'movie';
    }
    if (normalized.contains('ova')) return 'ova';
    if (normalized.contains('ona')) return 'ona';
    if (normalized.contains('спешл') || normalized.contains('special')) {
      return 'special';
    }
    if (normalized.contains('tv') || normalized.contains('сериал')) {
      return 'tv';
    }
    return '';
  }

  AnimeRelease _createReleaseFromYani(
    ShikimoriAnimeDetails details,
    YaniTrack track,
  ) {
    final episodes =
        track.episodes
            .map(
              (episode) => AnimeEpisode(
                id: 'yani:${_stableId(track.studio)}:${episode.ordinal}',
                ordinal: episode.ordinal,
                name: 'серия ${episode.ordinal}',
                hls480: null,
                hls720: null,
                hls1080: null,
                durationSeconds: episode.durationSeconds,
                previewPath: episode.screenshotUrl,
                openingStart: episode.openingStart,
                openingStop: episode.openingStop,
                endingStart: episode.endingStart,
                endingStop: episode.endingStop,
                sortOrder: episode.ordinal,
                resolverSource: episode.aksorId == null ? null : 'aksor',
                resolverId: episode.aksorId,
                embedUrl: episode.embedUrl,
                embedLabel: episode.embedLabel,
              ),
            )
            .toList()
          ..sort((a, b) => a.ordinal.compareTo(b.ordinal));

    return AnimeRelease(
      id: details.id,
      alias: '',
      name: details.russian.isNotEmpty ? details.russian : details.name,
      englishName: details.name,
      description: details.descriptionText,
      year: details.year,
      type: details.kind,
      season: null,
      ageRating: details.rating?.toUpperCase(),
      shikimoriRating: details.scoreValue,
      internalRating: null,
      posterPath: details.posterOriginalUrl ?? details.metadataPoster,
      posterThumbPath: details.posterUrl,
      backgroundPath: details.backgroundUrl ?? details.metadataBackground,
      isOngoing: details.isOngoing,
      isInProduction: details.status == 'anons',
      episodesTotal: episodes.length,
      genres: details.allGenres,
      members: const [],
      episodes: episodes,
      publishDay: null,
      blockedByGeo: false,
      blockedByCopyrights: false,
      freshAt: null,
      notification: null,
      shikimoriId: details.id,
    );
  }

  String _yaniVoiceId(int animeId, String studio) =>
      'yani_${animeId}_${_stableId(studio)}';

  String _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.toLowerCase().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String? _yaniStudioLogo(String studio) {
    final value = studio.toLowerCase();
    if (value.contains('anilibria') || value.contains('aniliberty')) {
      return 'https://anilibria.top/favicon.ico';
    }
    if (value.contains('animevost')) {
      return 'https://animevost.org/favicon.ico';
    }
    if (value.contains('anidub')) {
      return 'https://anidub.com/favicon.ico';
    }
    if (value.contains('onwave')) {
      return 'https://onwave.ru/favicon.ico';
    }
    if (value.contains('dreamcast')) {
      return 'https://dreamerscast.com/favicon.ico';
    }
    if (value.contains('jam')) {
      return 'https://jam-club.ru/favicon.ico';
    }
    if (value.contains('shiza')) {
      return 'https://shiza-project.com/favicon.ico';
    }
    if (value.contains('anistar')) {
      return 'https://anistar.org/favicon.ico';
    }
    if (value.contains('anibaza')) {
      return 'https://anibaza.ru/favicon.ico';
    }
    if (value.contains('studioband')) {
      return 'https://studioband.ru/favicon.ico';
    }
    return null;
  }

  AnimeRelease _createReleaseFromSource(
    String sourceId,
    SourceAnimeDetails details, {
    required int libraryId,
    required List<SourceEpisode> episodes,
  }) {
    return AnimeRelease(
      id: libraryId, // stable id for the library (Shikimori anime id)
      alias: '',
      name: details.russianTitle ?? details.title,
      englishName: details.title,
      description: details.description,
      year: details.year,
      type: details.kind,
      season: null,
      ageRating: null,
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
      episodes: episodes.map((episode) {
        final hls480 =
            episode.hlsUrls['480'] ??
            episode.mp4Urls['480'] ??
            episode.hlsUrls['auto'] ??
            episode.mp4Urls['auto'];
        final hls720 = episode.hlsUrls['720'] ?? episode.mp4Urls['720'];
        final hls1080 = episode.hlsUrls['1080'] ?? episode.mp4Urls['1080'];
        final hasDirect = hls480 != null || hls720 != null || hls1080 != null;
        return AnimeEpisode(
          id: '$sourceId:${episode.externalId}',
          ordinal: episode.ordinal,
          name: episode.title ?? 'серия ${episode.ordinal}',
          hls480: hls480,
          hls720: hls720,
          hls1080: hls1080,
          durationSeconds: episode.duration,
          previewPath: episode.posterUrl,
          openingStart: null,
          openingStop: null,
          endingStart: null,
          endingStop: null,
          sortOrder: episode.ordinal,
          resolverSource: hasDirect ? null : sourceId,
          resolverId: hasDirect ? null : episode.externalId,
        );
      }).toList(),
      publishDay: null,
      blockedByGeo: false,
      blockedByCopyrights: false,
      freshAt: null,
      notification: null,
      shikimoriId: null,
    );
  }

  /// Resolve an episode stream lazily for scraped sources.
  Future<String?> resolveEpisodeStream(
    AnimeEpisode episode, {
    String quality = 'auto',
  }) async {
    final direct = episode.hlsForQuality(quality) ?? episode.streamUrl;
    if (direct != null && direct.isNotEmpty) return direct;
    if (!episode.canResolve) return null;

    final key = '${episode.resolverSource}:${episode.resolverId}';
    final cached = _resolvedStreams[key];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      if (episode.resolverSource == 'aksor') {
        final url = await _yaniApi
            .resolveAksor(episode.resolverId!, quality: quality)
            .timeout(const Duration(seconds: 12));
        if (url != null && url.isNotEmpty) {
          _resolvedStreams[key] = url;
          return url;
        }
        return null;
      }
      final url = await _sourceManager.streamUrl(
        episode.resolverSource!,
        episode.resolverId!,
        quality: quality,
      );
      if (url != null && url.isNotEmpty) {
        _resolvedStreams[key] = url;
        return url;
      }
    } catch (_) {
      // Playback errors are surfaced by the player.
    }
    return null;
  }

  /// Enrich Shikimori details with AniLibria poster/background fallback.
  ShikimoriAnimeDetails _enrichWithAnilibriaPosters(
    ShikimoriAnimeDetails shikimori,
    List<AnimeRelease> releases,
  ) {
    if (releases.isEmpty) return shikimori;

    String? anilibriaPoster;
    String? anilibriaBackground;
    for (final r in releases) {
      if (anilibriaPoster == null &&
          r.posterUrl != null &&
          r.posterUrl!.isNotEmpty) {
        anilibriaPoster = r.posterUrl;
      }
      if (anilibriaBackground == null &&
          r.backgroundUrl != null &&
          r.backgroundUrl!.isNotEmpty) {
        anilibriaBackground = r.backgroundUrl;
      }
      if (anilibriaPoster != null && anilibriaBackground != null) break;
    }

    return shikimori.copyWith(
      anilibriaPosterFallback: anilibriaPoster,
      anilibriaBackgroundFallback: anilibriaBackground,
    );
  }

  // ===== Legacy compatibility =====

  Future<AnimeRelease> release(int id, {bool refresh = false}) =>
      _getAnilibriaRelease(id, refresh: refresh);

  Future<List<AnimeFranchise>> franchises(
    int releaseId, {
    bool refresh = false,
  }) {
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
    _popularCache.clear();
    _popularCacheAt.clear();
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

    _animeMetadataCache.clear();
    _animeMetadataCacheAt.clear();
    _animeMetadataRequests.clear();

    _animeWithSourcesCache.clear();
    _animeWithSourcesCacheAt.clear();
    _animeWithSourcesRequests.clear();
    _resolvedStreams.clear();
  }
}

/// Enriched details plus the raw Yani bundle, so the source builder can reuse
/// the studio tracks without hitting the API a second time.
class _AnimeMetadata {
  const _AnimeMetadata({required this.details, required this.yani});

  final ShikimoriAnimeDetails details;
  final YaniBundle? yani;
}

/// One voiceover/translation track inside a scraped source.
class _VoiceTrack {
  const _VoiceTrack({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.episodes,
    this.logoUrl,
  });

  final String key;
  final String title;
  final String subtitle;
  final List<SourceEpisode> episodes;
  final String? logoUrl;
}
