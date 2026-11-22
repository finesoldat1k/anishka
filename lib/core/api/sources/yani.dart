import 'dart:async';

import 'package:dio/dio.dart';

import '../yani_models.dart';
import 'source_provider.dart';
import 'unified_source.dart';

/// Yani source provider (YummyAnime API) — provides studio tracks, episodes, Aksor resolution for video playback.
class Yani implements SourceProvider {
  Yani({Dio? dio})
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

  @override
  String get displayName => 'yani';

  @override
  String get id => 'yani';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    // Yani search is not directly used for catalog search
    return const [];
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    // Yani source lookup is done via metadata findMetadata in the repository.
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async => null;

  /// Find YummyAnime entry and build unified sources (studio tracks).
  Future<List<UnifiedSource>?> findSources(
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
      if (details == null) continue;
      return _buildSources(details, videos, match.animeId);
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

  /// Build unified sources from YummyAnime data.
  List<UnifiedSource> _buildSources(
    YaniDetails details,
    List<YaniVideo> videos,
    int animeId,
  ) {
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
    for (final item in details.screenshots) {
      screenshotFor.putIfAbsent(item.ordinal, () => item.url);
    }

    final sources = <UnifiedSource>[];
    for (final entry in grouped.entries) {
      final episodes = <UnifiedEpisode>[];
      final players = <String>{};
      for (final ordinalEntry in entry.value.entries) {
        final options = ordinalEntry.value;
        if (options.isEmpty) continue;
        final embed = _bestEmbed(options);
        if (embed == null) continue;
        final embedUrl = embed.iframeUrl;
        if (embedUrl.isEmpty) continue;
        final resolverKind = _resolverKind(embedUrl);
        for (final option in options) {
          final label = _playerLabel(option.player);
          if (label.isNotEmpty) players.add(label);
        }
        episodes.add(
          UnifiedEpisode(
            id: 'yani:$animeId:${_stableId(entry.key)}:${ordinalEntry.key}',
            ordinal: ordinalEntry.key,
            title: 'серия ${ordinalEntry.key}',
            duration: embed.durationSeconds,
            posterUrl: screenshotFor[ordinalEntry.key],
            hls480: null,
            hls720: null,
            hls1080: null,
            openingStart: embed.openingStart,
            openingStop: embed.openingStop,
            endingStart: embed.endingStart,
            endingStop: embed.endingStop,
            embedUrl: embedUrl,
            embedLabel: _playerLabel(embed.player),
            resolverSource: resolverKind,
            resolverId: resolverKind == null ? null : embedUrl,
          ),
        );
      }
      episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
      if (episodes.isEmpty) continue;

      sources.add(
        UnifiedSource(
          id: 'yani:$animeId:${_stableId(entry.key)}',
          providerId: 'yani',
          title: entry.key,
          subtitle: 'yani · ${players.join(', ')}',
          logoUrl: _studioLogo(entry.key),
          episodeCount: episodes.length,
          episodes: episodes,
          hasDirectStreams: false,
          requiresResolution: true,
        ),
      );
    }

    sources.sort((a, b) {
      final byPriority = _studioPriority(a.title)
          .compareTo(_studioPriority(b.title));
      if (byPriority != 0) return byPriority;
      return a.title.compareTo(b.title);
    });
    return sources;
  }

  YaniVideo? _bestEmbed(List<YaniVideo> options) {
    final sorted = [...options]
      ..sort((a, b) {
        final byResolver = _resolverRank(a.iframeUrl)
            .compareTo(_resolverRank(b.iframeUrl));
        if (byResolver != 0) return byResolver;
        final byPlayer = _playerRank(a.player).compareTo(_playerRank(b.player));
        if (byPlayer != 0) return byPlayer;
        return a.ordinal.compareTo(b.ordinal);
      });
    return sorted.isEmpty ? null : sorted.first;
  }

  // Static helper methods
  static String _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.toLowerCase().codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String? _studioLogo(String studio) {
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

  static int _studioPriority(String studio) {
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

  static String? _studioName(String? raw) {
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

  static String _playerLabel(String player) {
    var value = player.trim();
    for (final prefix in const ['плеер ', 'player ']) {
      if (value.toLowerCase().startsWith(prefix)) {
        value = value.substring(prefix.length).trim();
        break;
      }
    }
    return value;
  }

  static int _resolverRank(String? url) {
    return _resolverKind(url) == null ? 10 : 0;
  }

  /// Map an embed URL to the resolver registered in the app.
  static String? _resolverKind(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    if (host.contains('kodik') || host.contains('anivod') || host.contains('aniqit')) {
      return 'kodik';
    }
    if (host.contains('aniboom')) return 'aniboom';
    if (host.contains('sibnet')) return 'sibnet';
    if (host.contains('cdnvideohub') || host.contains('animego')) {
      return 'cdnvideohub';
    }
    if (host.contains('aksor')) return 'aksor';
    if (host.contains('alloha')) return 'alloha';
    return null;
  }

  static int _playerRank(String player) {
    final value = player.toLowerCase();
    if (value.contains('kodik')) return 0;
    if (value.contains('alloha')) return 1;
    if (value.contains('aksor')) return 2;
    if (value.contains('cvh') || value.contains('cdnvideohub')) return 3;
    return 5;
  }

  static List<Map<String, dynamic>> _responseList(dynamic data) {
    final value = data is Map ? data['response'] : data;
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  static Map<String, dynamic>? _responseMap(dynamic data) {
    final value = data is Map ? data['response'] : data;
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}
