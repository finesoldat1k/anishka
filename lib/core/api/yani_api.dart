import 'package:dio/dio.dart';

/// Client for the public YummyAnime API (`api.yani.tv`).
///
/// YummyAnime aggregates real voiceover studios (`AniLibria`, `AnimeVost`,
/// `AniDUB`, `JAM`, `SHIZA Project`, ...) and exposes their embedded players.
/// The API is public, sends `access-control-allow-origin: *` and is therefore
/// usable from Flutter web without a proxy.
class YaniApi {
  YaniApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.yani.tv',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'anishka/1.0',
              },
            ),
          );

  final Dio _dio;

  /// Find the YummyAnime entry whose `remote_ids.shikimori_id` matches [id].
  ///
  /// Several title variants are tried; the first exact remote-id match wins.
  Future<YaniBundle?> findBundle(
    int shikimoriId, {
    required List<String> queries,
  }) async {
    for (final query in queries) {
      final text = query.trim();
      if (text.isEmpty) continue;
      final match = await _findByQuery(text, shikimoriId);
      if (match == null) continue;
      final detailsFuture = _details(match.animeId);
      final videosFuture = _videos(match.animeId);
      final details = await detailsFuture;
      final videos = await videosFuture;
      final tracks = _buildTracks(videos, details);
      return YaniBundle(anime: match, details: details, tracks: tracks);
    }
    return null;
  }

  Future<YaniAnime?> _findByQuery(String query, int shikimoriId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/anime',
        queryParameters: {'q': query, 'limit': 24},
      );
      for (final item in _responseList(response.data)) {
        final anime = YaniAnime.fromJson(item);
        if (anime.animeId <= 0) continue;
        if (anime.shikimoriId == shikimoriId) return anime;
      }
    } catch (_) {
      // Another title variant may still work.
    }
    return null;
  }

  Future<YaniDetails?> _details(int animeId) async {
    try {
      final response = await _dio.get<dynamic>('/anime/$animeId');
      final map = _responseMap(response.data);
      if (map == null) return null;
      return YaniDetails.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<List<YaniVideo>> _videos(int animeId) async {
    try {
      final response = await _dio.get<dynamic>('/anime/$animeId/videos');
      return _responseList(response.data)
          .map(YaniVideo.fromJson)
          .where((video) => video.ordinal > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Turn the flat video list into one track per real studio.
  ///
  /// Subtitles are intentionally dropped: the voiceover page is about
  /// studios, not subtitle groups. For each episode we keep the most reliable
  /// embedded player and, when available, the Aksor id for native playback.
  List<YaniTrack> _buildTracks(List<YaniVideo> videos, YaniDetails? details) {
    final grouped = <String, Map<int, List<YaniVideo>>>{};
    for (final video in videos) {
      final studio = _studioName(video.dubbing);
      if (studio == null || studio.isEmpty) continue;
      grouped
          .putIfAbsent(studio, () => <int, List<YaniVideo>>{})
          .putIfAbsent(video.ordinal, () => <YaniVideo>[])
          .add(video);
    }

    final screenshotFor = <int, String>{};
    for (final item in details?.screenshots ?? const <YaniScreenshot>[]) {
      screenshotFor.putIfAbsent(item.ordinal, () => item.url);
    }

    final tracks = <YaniTrack>[];
    for (final entry in grouped.entries) {
      final episodes = <YaniEpisode>[];
      final players = <String>{};
      for (final ordinalEntry in entry.value.entries) {
        final options = ordinalEntry.value;
        if (options.isEmpty) continue;
        final embed = _bestEmbed(options);
        if (embed == null) continue;
        final aksorOptions = options
            .where((video) => video.player.toLowerCase().contains('aksor'))
            .toList();
        final aksor = aksorOptions.isEmpty ? null : aksorOptions.first;
        for (final option in options) {
          final label = _playerLabel(option.player);
          if (label.isNotEmpty) players.add(label);
        }
        episodes.add(
          YaniEpisode(
            ordinal: ordinalEntry.key,
            embedUrl: embed.iframeUrl,
            embedLabel: _playerLabel(embed.player),
            aksorId: aksor?.iframeUrl == null
                ? null
                : _aksorVideoId(aksor!.iframeUrl),
            durationSeconds: embed.durationSeconds,
            screenshotUrl: screenshotFor[ordinalEntry.key],
            openingStart: embed.openingStart,
            openingStop: embed.openingStop,
            endingStart: embed.endingStart,
            endingStop: embed.endingStop,
          ),
        );
      }
      episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
      if (episodes.isEmpty) continue;
      tracks.add(
        YaniTrack(
          studio: entry.key,
          players: players.toList()..sort(),
          episodes: episodes,
        ),
      );
    }

    tracks.sort((a, b) {
      final byPriority = _studioPriority(a.studio)
          .compareTo(_studioPriority(b.studio));
      if (byPriority != 0) return byPriority;
      return a.studio.compareTo(b.studio);
    });
    return tracks;
  }

  YaniVideo? _bestEmbed(List<YaniVideo> options) {
    final sorted = [...options]
      ..sort((a, b) {
        final byPlayer = _playerRank(a.player).compareTo(_playerRank(b.player));
        if (byPlayer != 0) return byPlayer;
        return a.ordinal.compareTo(b.ordinal);
      });
    return sorted.isEmpty ? null : sorted.first;
  }

  int _playerRank(String player) {
    final value = player.toLowerCase();
    if (value.contains('kodik')) return 0;
    if (value.contains('alloha')) return 1;
    if (value.contains('aksor')) return 2;
    if (value.contains('cvh') || value.contains('cdnvideohub')) return 3;
    return 5;
  }

  int _studioPriority(String studio) {
    final value = studio.toLowerCase();
    const order = [
      'aniliberty',
      'anilibria',
      'animevost',
      'anidub',
      'onwave',
      'dreamcast',
      'комната диди',
      'jam',
      'shiza',
      'anistar',
      'anibaza',
      'studioband',
      'дублированный',
      'animedia',
      '2x2',
      'anirise',
      'anifilm',
    ];
    final index = order.indexWhere((name) => value.contains(name));
    return index < 0 ? order.length : index;
  }

  String? _studioName(String? raw) {
    var value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.startsWith('субтитры') || lower.startsWith('subtitle')) {
      return null;
    }
    for (final prefix in const ['озвучка ', 'озвучка:', 'дубляж ']) {
      if (lower.startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }
    if (value.isEmpty) return null;
    return value;
  }

  String _playerLabel(String player) {
    var value = player.trim();
    for (final prefix in const ['плеер ', 'player ']) {
      if (value.toLowerCase().startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }
    return value;
  }

  String? _aksorVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.toLowerCase().contains('aksor')) return null;
    if (uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.last;
  }

  /// Resolve an Aksor video to a direct MPD/HLS stream.
  ///
  /// Aksor does not send CORS headers, so this is used on native platforms
  /// only. Web playback uses the embedded player instead.
  Future<String?> resolveAksor(
    String videoId, {
    String quality = 'auto',
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        'https://player.aksor.tv/api/video/$videoId',
      );
      final data = response.data;
      if (data is! Map) return null;
      final qualities = data['qualities'];
      if (qualities is! Map) return null;
      final desired = _qualityKeys(quality);
      for (final key in desired) {
        final value = qualities[key];
        if (value is String && value.isNotEmpty) return value;
      }
      for (final value in qualities.values) {
        if (value is String && value.isNotEmpty) return value;
      }
    } catch (_) {
      // The player will show a friendly error.
    }
    return null;
  }

  List<String> _qualityKeys(String quality) => switch (quality) {
    '1080' => const ['q1080', 'q720', 'q480', 'q360'],
    '720' => const ['q720', 'q1080', 'q480', 'q360'],
    '480' => const ['q480', 'q720', 'q360', 'q1080'],
    _ => const ['q1080', 'q720', 'q480', 'q360', 'q2k', 'q4k'],
  };

  List<Map<String, dynamic>> _responseList(dynamic data) {
    final value = data is Map ? data['response'] : data;
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Map<String, dynamic>? _responseMap(dynamic data) {
    final value = data is Map ? data['response'] : data;
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}

class YaniBundle {
  const YaniBundle({
    required this.anime,
    required this.details,
    required this.tracks,
  });

  final YaniAnime anime;
  final YaniDetails? details;
  final List<YaniTrack> tracks;
}

class YaniAnime {
  const YaniAnime({
    required this.animeId,
    required this.title,
    required this.shikimoriId,
    this.posterUrl,
    this.year,
  });

  final int animeId;
  final String title;
  final int? shikimoriId;
  final String? posterUrl;
  final int? year;

  factory YaniAnime.fromJson(Map<String, dynamic> json) {
    final remote = json['remote_ids'];
    final poster = json['poster'];
    return YaniAnime(
      animeId: _asInt(json['anime_id']) ?? _asInt(json['id']) ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      shikimoriId: remote is Map ? _asInt(remote['shikimori_id']) : null,
      posterUrl: poster is Map
          ? _normalizeUrl(
              poster['fullsize'] ?? poster['big'] ?? poster['medium'],
            )
          : null,
      year: _asInt(json['year']),
    );
  }
}

class YaniDetails {
  const YaniDetails({
    this.posterUrl,
    this.backgroundUrl,
    this.studios = const [],
    this.screenshots = const [],
  });

  final String? posterUrl;
  final String? backgroundUrl;
  final List<String> studios;
  final List<YaniScreenshot> screenshots;

  factory YaniDetails.fromJson(Map<String, dynamic> json) {
    final poster = json['poster'];
    final studios = json['studios'];
    final shots = json['random_screenshots'];
    final screenshots = <YaniScreenshot>[];
    if (shots is List) {
      for (final item in shots) {
        if (item is Map) {
          screenshots.add(
            YaniScreenshot.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    return YaniDetails(
      posterUrl: poster is Map
          ? _normalizeUrl(
              poster['fullsize'] ?? poster['big'] ?? poster['medium'],
            )
          : null,
      backgroundUrl: _normalizeUrl(json['background']),
      studios: studios is List
          ? studios
                .whereType<Map>()
                .map((item) => (item['title'] as String? ?? '').trim())
                .where((value) => value.isNotEmpty)
                .toList()
          : const [],
      screenshots: screenshots,
    );
  }
}

class YaniScreenshot {
  const YaniScreenshot({required this.ordinal, required this.url});

  final int ordinal;
  final String url;

  factory YaniScreenshot.fromJson(Map<String, dynamic> json) {
    final sizes = json['sizes'];
    final raw = sizes is Map ? sizes['full'] ?? sizes['small'] : null;
    return YaniScreenshot(
      ordinal: _asInt(json['episode']) ?? 0,
      url: _normalizeUrl(raw) ?? '',
    );
  }
}

class YaniVideo {
  const YaniVideo({
    required this.ordinal,
    required this.iframeUrl,
    required this.player,
    required this.dubbing,
    this.durationSeconds,
    this.openingStart,
    this.openingStop,
    this.endingStart,
    this.endingStop,
  });

  final int ordinal;
  final String iframeUrl;
  final String player;
  final String dubbing;
  final int? durationSeconds;
  final int? openingStart;
  final int? openingStop;
  final int? endingStart;
  final int? endingStop;

  factory YaniVideo.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map ? data : const {};
    final skips = json['skips'];
    final skipMap = skips is Map ? skips : const {};
    final opening = skipMap['opening'];
    final ending = skipMap['ending'];
    final openingMap = opening is Map ? opening : const {};
    final endingMap = ending is Map ? ending : const {};
    return YaniVideo(
      ordinal: int.tryParse('${json['number'] ?? ''}') ?? 0,
      iframeUrl: _normalizeUrl(json['iframe_url']) ?? '',
      player: (map['player'] as String? ?? '').trim(),
      dubbing: (map['dubbing'] as String? ?? '').trim(),
      durationSeconds: _asInt(json['duration']),
      openingStart: _asInt(openingMap['time']),
      openingStop: _skipStop(openingMap),
      endingStart: _asInt(endingMap['time']),
      endingStop: _skipStop(endingMap),
    );
  }

  static int? _skipStop(Map<dynamic, dynamic> skip) {
    final start = _asInt(skip['time']);
    final length = _asInt(skip['length']);
    if (start == null || length == null) return null;
    return start + length;
  }
}

class YaniTrack {
  const YaniTrack({
    required this.studio,
    required this.players,
    required this.episodes,
  });

  final String studio;
  final List<String> players;
  final List<YaniEpisode> episodes;
}

class YaniEpisode {
  const YaniEpisode({
    required this.ordinal,
    required this.embedUrl,
    required this.embedLabel,
    required this.aksorId,
    this.durationSeconds,
    this.screenshotUrl,
    this.openingStart,
    this.openingStop,
    this.endingStart,
    this.endingStop,
  });

  final int ordinal;
  final String embedUrl;
  final String embedLabel;
  final String? aksorId;
  final int? durationSeconds;
  final String? screenshotUrl;
  final int? openingStart;
  final int? openingStop;
  final int? endingStart;
  final int? endingStop;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

String? _normalizeUrl(dynamic raw) {
  final value = raw is String ? raw.trim() : '';
  if (value.isEmpty) return null;
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return null;
}
