import 'dart:convert';

import 'package:dio/dio.dart';

import '../json_utils.dart';
import 'embed/embed_http.dart';
import 'source_provider.dart';
import 'unified_source.dart';

/// AniLibMe provider backed by the public CDNLibs REST API.
///
/// Episode details contain a `players` list: Kodik embeds and direct MP4
/// qualities from the animelib CDN. Both are mapped to unified episodes.
class AnilibMe implements SourceProvider {
  AnilibMe({Dio? dio}) : _dio = dio ?? _createDio();

  static const apiBase = 'https://api.cdnlibs.org/api';
  static const _animelibVideoBase =
      'https://video1.cdnlibs.org/.%D0%B0s/';

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: apiBase,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 18),
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'Accept': 'application/json',
          'Origin': 'https://animelib.org',
          'Referer': 'https://animelib.org/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ),
    );
  }

  @override
  String get displayName => 'anilibme';

  @override
  String get id => 'anilibme';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final data = await _getJson(
      '/anime',
      query: {
        'fields[]': ['rate', 'rate_avg', 'releaseDate'],
        'site_id[]': [1, 3],
        'q': value,
      },
    );
    final items = asMapList(data?['data']);
    final results = <UnifiedSource>[];
    for (final item in items) {
      final slug = item['slug_url']?.toString() ?? '';
      if (slug.isEmpty) continue;
      final title = _title(item);
      if (title.isEmpty) continue;
      final cover = asMap(item['cover']);
      results.add(
        UnifiedSource(
          id: _sourceId(slug, '', ''),
          providerId: 'anilibme',
          title: title,
          subtitle: 'anilibme',
          logoUrl: cover['default']?.toString(),
        ),
      );
    }
    return results;
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    final hint = nameHint?.trim() ?? '';
    if (hint.isEmpty) return const [];
    final candidates = await search(hint);
    if (candidates.isEmpty) return const [];

    final ranked = [...candidates]
      ..sort((a, b) => _titleScore(b.title, hint)
          .compareTo(_titleScore(a.title, hint)));
    for (final candidate in ranked.take(3)) {
      if (_titleScore(candidate.title, hint) <= 0) continue;
      final slug = _parseSourceId(candidate.id)?.slug;
      if (slug == null) continue;
      final sources = await _buildFromSlug(slug);
      if (sources.isNotEmpty) return sources;
    }
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final parsed = _parseSourceId(sourceId);
    if (parsed == null) return null;
    final sources = await _buildFromSlug(parsed.slug);
    if (sources.isEmpty) return null;
    for (final source in sources) {
      if (source.id == sourceId) return source;
    }
    return sources.first;
  }

  // ============ API ============

  Future<Map<String, dynamic>?> _getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<String>(
        path,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Accept': 'application/json',
            'Origin': 'https://animelib.org',
            'Referer': 'https://animelib.org/',
          },
        ),
      );
      final body = response.data ?? '';
      if (!body.trimLeft().startsWith('{')) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Ignore and return null.
    }
    return null;
  }

  Future<List<UnifiedSource>> _buildFromSlug(String slug) async {
    final episodesData = await _getJson(
      '/episodes',
      query: {'anime_id': slug},
    );
    final episodeItems = asMapList(episodesData?['data']);
    if (episodeItems.isEmpty) return const [];

    final details = await _mapPool(
      episodeItems,
      (item) => _fetchEpisode(item),
    );

    // key -> (title, subtitle, player, team, episodes)
    final groups = <String, _AnilibGroup>{};
    for (var index = 0; index < episodeItems.length; index++) {
      final item = episodeItems[index];
      final detail = details[index];
      if (detail == null) continue;
      final ordinal = asInt(item['number']) ?? index + 1;
      final episodeName = item['name']?.toString().trim() ?? '';
      final poster = null;

      for (final player in detail) {
        final playerName = player.player.toLowerCase();
        final teamName = player.team;
        final key = '$playerName::$teamName';
        final group = groups.putIfAbsent(
          key,
          () => _AnilibGroup(
            player: playerName,
            team: teamName,
          ),
        );

        if (playerName == 'kodik') {
          final url = absoluteUrl(player.src, base: 'https://kodik.info');
          if (url == null) continue;
          group.episodes.add(
            UnifiedEpisode(
              id: 'anilibme:$slug:$key:$ordinal',
              ordinal: ordinal,
              title: episodeName.isEmpty ? 'серия $ordinal' : episodeName,
              posterUrl: poster,
              embedUrl: url,
              embedLabel: teamName,
              resolverSource: 'kodik',
              resolverId: url,
            ),
          );
        } else if (playerName == 'animelib') {
          final qualities = player.qualities;
          if (qualities.isEmpty) continue;
          group.episodes.add(
            UnifiedEpisode(
              id: 'anilibme:$slug:$key:$ordinal',
              ordinal: ordinal,
              title: episodeName.isEmpty ? 'серия $ordinal' : episodeName,
              posterUrl: poster,
              hls480: qualities[480] ?? qualities[360],
              hls720: qualities[720],
              hls1080: qualities[1080],
              streamHeaders: const {
                'Referer': 'https://v3.animelib.org',
                'User-Agent': embedUserAgent,
              },
            ),
          );
        }
      }
    }

    final sources = <UnifiedSource>[];
    for (final group in groups.values) {
      if (group.episodes.isEmpty) continue;
      group.episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
      final title = group.team.isEmpty ? group.player : group.team;
      sources.add(
        UnifiedSource(
          id: _sourceId(slug, group.player, group.team),
          providerId: 'anilibme',
          title: title,
          subtitle: 'anilibme · ${group.player}',
          episodeCount: group.episodes.length,
          episodes: group.episodes,
          hasDirectStreams: group.player == 'animelib',
          requiresResolution: group.player != 'animelib',
        ),
      );
    }
    sources.sort((a, b) {
      if (a.hasDirectStreams != b.hasDirectStreams) {
        return a.hasDirectStreams ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });
    return sources;
  }

  Future<List<_AnilibPlayer>?> _fetchEpisode(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final data = await _getJson('/episodes/$id');
    final detail = asMap(data?['data']);
    final players = asMapList(detail['players']);
    if (players.isEmpty) return null;

    final result = <_AnilibPlayer>[];
    for (final player in players) {
      final name = player['player']?.toString() ?? '';
      if (name.isEmpty) continue;
      final team = asMap(player['team'])['name']?.toString().trim() ?? '';
      final qualities = <int, String>{};
      final video = asMap(player['video']);
      for (final quality in asMapList(video['quality'])) {
        final value = asInt(quality['quality']);
        final href = quality['href']?.toString() ?? '';
        if (value == null || href.isEmpty) continue;
        final url = href.startsWith('http')
            ? href
            : '$_animelibVideoBase${href.startsWith('/') ? href.substring(1) : href}';
        qualities[value] = url;
      }
      result.add(
        _AnilibPlayer(
          player: name,
          team: team,
          src: player['src']?.toString() ?? '',
          qualities: qualities,
        ),
      );
    }
    return result.isEmpty ? null : result;
  }

  Future<List<T?>> _mapPool<T>(
    List<Map<String, dynamic>> items,
    Future<T?> Function(Map<String, dynamic> item) action, {
    int concurrency = 6,
  }) async {
    final results = <T?>[];
    for (var start = 0; start < items.length; start += concurrency) {
      final end = start + concurrency > items.length
          ? items.length
          : start + concurrency;
      final chunk = await Future.wait(
        items.sublist(start, end).map(action),
      );
      results.addAll(chunk);
    }
    return results;
  }

  static String _title(Map<String, dynamic> item) {
    for (final key in const ['rus_name', 'name', 'eng_name']) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _sourceId(String slug, String player, String team) {
    return 'anilibme::${Uri.encodeComponent(slug)}::'
        '${Uri.encodeComponent(player)}::${Uri.encodeComponent(team)}';
  }

  static ({String slug, String player, String team})? _parseSourceId(
    String sourceId,
  ) {
    final parts = sourceId.split('::');
    if (parts.length < 2) return null;
    final slug = Uri.decodeComponent(parts[1]);
    if (slug.isEmpty) return null;
    return (
      slug: slug,
      player: parts.length > 2 ? Uri.decodeComponent(parts[2]) : '',
      team: parts.length > 3 ? Uri.decodeComponent(parts[3]) : '',
    );
  }

  static int _titleScore(String title, String query) {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final left = normalize(title);
    final right = normalize(query);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 100;
    if (left.contains(right) || right.contains(left)) return 60;
    return left.split(' ').toSet().intersection(right.split(' ').toSet()).length *
        10;
  }
}

class _AnilibGroup {
  _AnilibGroup({required this.player, required this.team});

  final String player;
  final String team;
  final List<UnifiedEpisode> episodes = [];
}

class _AnilibPlayer {
  const _AnilibPlayer({
    required this.player,
    required this.team,
    required this.src,
    required this.qualities,
  });

  final String player;
  final String team;
  final String src;
  final Map<int, String> qualities;
}
