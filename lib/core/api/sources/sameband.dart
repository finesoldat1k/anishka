import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'embed/embed_http.dart';
import 'source_provider.dart';
import 'unified_source.dart';

/// SameBand source provider.
///
/// The site exposes an iframe player whose Playerjs playlist contains direct
/// HLS URLs for every quality, so no separate resolver is required.
class SameBand implements SourceProvider {
  SameBand({Dio? dio}) : _dio = dio ?? _createDio();

  static const baseUrl = 'https://sameband.studio';

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 18),
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );
  }

  @override
  String get displayName => 'sameband';

  @override
  String get id => 'sameband';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    try {
      final response = await _dio.post<String>(
        '/index.php?do=search',
        data: {
          'do': 'search',
          'subaction': 'search',
          'search_start': '0',
          'full_search': '0',
          'result_from': '1',
          'story': value,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final body = response.data ?? '';
      if (body.isEmpty) return const [];
      final document = html_parser.parse(body);
      final results = <UnifiedSource>[];
      for (final item in document.querySelectorAll('.col-auto')) {
        final link = item.querySelector('a[href]');
        final url = absoluteUrl(link?.attributes['href'], base: baseUrl);
        if (url == null) continue;
        final poster = item.querySelector('.poster[title]');
        final title = (poster?.attributes['title'] ?? poster?.text ?? '').trim();
        if (title.isEmpty) continue;
        final image = item.querySelector('img.swiper-lazy[src]') ??
            item.querySelector('img[src]') ??
            item.querySelector('img[data-src]');
        results.add(
          UnifiedSource(
            id: _sourceId(url),
            providerId: 'sameband',
            title: title,
            subtitle: 'sameband',
            logoUrl: absoluteUrl(
              image?.attributes['src'] ?? image?.attributes['data-src'],
              base: baseUrl,
            ),
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
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
      final source = await getSource(candidate.id);
      if (source != null && source.episodes.isNotEmpty) return [source];
    }
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final url = _parseSourceId(sourceId);
    if (url == null) return null;
    try {
      final response = await _dio.get<String>(url);
      final body = response.data ?? '';
      if (body.isEmpty) return null;
      final document = html_parser.parse(body);
      final title = document.querySelector('h1.p-0.m-0')?.text.trim() ??
          document.querySelector('h1')?.text.trim() ??
          '';
      if (title.isEmpty) return null;
      final description = document
              .querySelectorAll('.limiter p')
              .map((item) => item.text.trim())
              .where((item) => item.isNotEmpty)
              .join(' ');
      final image = document.querySelector('.image > img[src]') ??
          document.querySelector('.image img[src]');
      final playerUrl = absoluteUrl(
        document.querySelector('.player > .player-content > iframe[src]')
                ?.attributes['src'] ??
            document.querySelector('.player iframe[src]')?.attributes['src'],
        base: baseUrl,
      );

      final episodes = playerUrl == null
          ? const <UnifiedEpisode>[]
          : await _fetchEpisodes(playerUrl);

      return UnifiedSource(
        id: sourceId,
        providerId: 'sameband',
        title: title,
        subtitle: description.isEmpty ? 'sameband' : 'sameband · $description',
        logoUrl: absoluteUrl(image?.attributes['src'], base: baseUrl),
        episodeCount: episodes.length,
        episodes: episodes,
        hasDirectStreams: episodes.isNotEmpty,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<UnifiedEpisode>> _fetchEpisodes(String playerUrl) async {
    try {
      final player = await _dio.get<String>(playerUrl);
      final playerBody = player.data ?? '';
      if (playerBody.isEmpty) return const [];

      final match = RegExp(
        r'''Playerjs[^>]+file:\s*["']([^>]+)["']''',
      ).firstMatch(playerBody);
      final rawPlaylist = match?.group(1);
      if (rawPlaylist == null || rawPlaylist.isEmpty) return const [];

      final playlistUrl = absoluteUrl(rawPlaylist, base: baseUrl);
      if (playlistUrl == null) return const [];
      final response = await _dio.get<String>(playlistUrl);
      final body = response.data ?? '';
      if (body.isEmpty) return const [];
      return parsePlaylist(body);
    } catch (_) {
      return const [];
    }
  }

  /// Convert a Playerjs JSON playlist into unified episodes.
  ///
  /// Exposed for tests.
  static List<UnifiedEpisode> parsePlaylist(String body) {
    final trimmed = body.trim();
    if (!trimmed.startsWith('[')) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return const [];
      final episodes = <UnifiedEpisode>[];
      var ordinal = 0;
      for (final item in decoded) {
        if (item is! Map) continue;
        final file = item['file']?.toString() ?? '';
        if (file.isEmpty) continue;
        ordinal++;
        final qualities = <String, String>{};
        for (final part in file.split(',')) {
          final value = part.trim();
          final match = RegExp(r'^\[(\d+)p\](.+)$').firstMatch(value);
          if (match == null) continue;
          final quality = match.group(1)!;
          final path = match.group(2)!;
          final url = absoluteUrl(path, base: baseUrl);
          if (url != null) qualities[quality] = url;
        }
        if (qualities.isEmpty) continue;
        episodes.add(
          UnifiedEpisode(
            id: 'sameband:$ordinal',
            ordinal: ordinal,
            title: 'серия $ordinal',
            hls480: qualities['480'],
            hls720: qualities['720'],
            hls1080: qualities['1080'] ?? qualities['1080p'],
          ),
        );
      }
      return episodes;
    } catch (_) {
      return const [];
    }
  }

  static String _sourceId(String url) =>
      'sameband::${Uri.encodeComponent(url)}';

  static String? _parseSourceId(String sourceId) {
    final parts = sourceId.split('::');
    if (parts.length < 2) return null;
    final value = Uri.decodeComponent(parts[1]);
    return value.isEmpty ? null : value;
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
