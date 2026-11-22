// Shared Yani models used by both metadata and source providers.

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

class YaniMetadata {
  const YaniMetadata({
    this.posterUrl,
    this.backgroundUrl,
    this.studios = const [],
    this.screenshots = const [],
  });

  final String? posterUrl;
  final String? backgroundUrl;
  final List<String> studios;
  final List<String> screenshots;
}
