// AnimeVost video source: DLE search, episode ids and direct MP4 extraction.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/models/video_source.dart';

class AnimeVostVideoSource implements VideoSource {
  AnimeVostVideoSource({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://animevost.org',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'ru,en;q=0.8',
              },
            ),
          );

  final Dio _dio;
  final Map<String, String?> _streamCache = {};

  @override
  String get sourceId => 'animevost';

  @override
  String get displayName => 'animevost';

  @override
  int get priority => 2;

  @override
  List<String> get availableQualities => const ['720', 'auto'];

  @override
  Future<bool> healthCheck() async {
    try {
      await _dio.get('/rss.xml');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<SourceAnimeEntry>> search(String query, {int limit = 50}) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    try {
      // AnimeVost's DLE search only works with a POSTed `story` field.
      final response = await _dio.post<String>(
        '/index.php?do=search',
        data: {
          'do': 'search',
          'subaction': 'search',
          'story': value,
          'full_search': '0',
          'result_from': '1',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      return _parseSearchResults(response.data ?? '', limit);
    } catch (_) {
      return const [];
    }
  }

  List<SourceAnimeEntry> _parseSearchResults(String html, int limit) {
    final results = <SourceAnimeEntry>[];
    try {
      final document = html_parser.parse(html);
      final items = document.querySelectorAll('.shortstory');
      for (final item in items.take(limit)) {
        final link = item.querySelector('.shortstoryHead h2 a, h2 a');
        final href = link?.attributes['href'];
        if (link == null || href == null || href.isEmpty) continue;

        final rawTitle = link.text.trim();
        final blockText = item.text;
        final year = _firstInt(
          RegExp(r'Год выхода:\s*(\d{4})').firstMatch(blockText)?.group(1),
        );
        final kind = RegExp(r'Тип:\s*([^\n]+)')
            .firstMatch(blockText)
            ?.group(1)
            ?.trim();
        final episodes = _firstInt(
          RegExp(r'Количество серий:\s*(\d+)').firstMatch(blockText)?.group(1),
        );
        final img = item.querySelector('.shortstoryContent img, img');
        final poster = img?.attributes['src'] ?? img?.attributes['data-src'];

        final russianTitle = _cleanSearchTitle(rawTitle);
        results.add(
          SourceAnimeEntry(
            sourceId: sourceId,
            externalId: _absoluteUrl(href),
            title: rawTitle,
            russianTitle: russianTitle,
            posterUrl: poster == null ? null : _resolveUrl(poster),
            year: year,
            kind: kind,
            episodes: episodes,
            status: null,
            score: null,
          ),
        );
      }
    } catch (_) {
      // Scraping failures are non-fatal: the source simply has no results.
    }
    return results;
  }

  String _cleanSearchTitle(String raw) {
    var title = raw;
    final slash = title.indexOf(' / ');
    if (slash > 0) title = title.substring(0, slash);
    title = title.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    return title;
  }

  int? _firstInt(String? value) => value == null ? null : int.tryParse(value);

  String _absoluteUrl(String href) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('//')) return 'https:$href';
    return 'https://animevost.org${href.startsWith('/') ? '' : '/'}$href';
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return 'https://animevost.org${url.startsWith('/') ? '' : '/'}$url';
  }

  @override
  Future<SourceAnimeDetails?> getDetails(String externalId) async {
    try {
      final response = await _dio.get<String>(
        _absoluteUrl(externalId),
        options: Options(responseType: ResponseType.plain),
      );
      return _parseDetails(externalId, response.data ?? '');
    } catch (_) {
      return null;
    }
  }

  SourceAnimeDetails? _parseDetails(String externalId, String html) {
    try {
      final document = html_parser.parse(html);
      final pageText = document.body?.text ?? '';

      final ogTitle = document
          .querySelector('meta[property="og:title"]')
          ?.attributes['content'];
      final heading = document.querySelector('h1')?.text.trim();
      final rawTitle = _stripSiteSuffix(ogTitle ?? heading ?? '');
      final russianTitle = _cleanSearchTitle(rawTitle);

      final ogImage = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
      final poster =
          ogImage ?? document.querySelector('img')?.attributes['src'];

      final description =
          document
              .querySelector('meta[property="og:description"]')
              ?.attributes['content']
              ?.trim() ??
          document.querySelector('.full-text')?.text.trim();

      final year = _firstInt(
        RegExp(r'Год выхода:\s*(\d{4})').firstMatch(pageText)?.group(1),
      );
      final kind = RegExp(r'Тип:\s*([^\n]+)')
          .firstMatch(pageText)
          ?.group(1)
          ?.trim();
      final score = double.tryParse(
        RegExp(r'Рейтинг:\s*([\d.]+)').firstMatch(pageText)?.group(1) ?? '',
      );

      final episodes = parseAnimeVostEpisodes(html);

      return SourceAnimeDetails(
        sourceId: sourceId,
        externalId: externalId,
        title: rawTitle,
        russianTitle: russianTitle,
        description: description,
        posterUrl: poster == null ? null : _resolveUrl(poster),
        backgroundUrl: poster == null ? null : _resolveUrl(poster),
        year: year,
        kind: kind,
        status: null,
        episodes: episodes.length,
        score: score?.toString(),
        genres: _parseGenres(pageText),
        episodesList: episodes,
      );
    } catch (_) {
      return null;
    }
  }

  String _stripSiteSuffix(String value) {
    final marker = value.indexOf(' »');
    return (marker > 0 ? value.substring(0, marker) : value).trim();
  }

  List<String> _parseGenres(String pageText) {
    final match = RegExp(r'Жанр:\s*([^\n]+)').firstMatch(pageText);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return const [];
    return value
        .split(',')
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .toList();
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String externalId) async {
    final details = await getDetails(externalId);
    return details?.episodesList ?? const [];
  }

  @override
  Future<String?> getStreamUrl(String sourceEpisodeId, String quality) async {
    final id = sourceEpisodeId.trim();
    if (id.isEmpty) return null;
    if (_streamCache.containsKey(id)) return _streamCache[id];

    final url = await _resolveEpisodeStream(id);
    _streamCache[id] = url;
    return url;
  }

  Future<String?> _resolveEpisodeStream(String id) async {
    // frame5 contains a list of working mirrors for the episode.
    try {
      final response = await _dio.get<String>(
        '/frame5.php',
        queryParameters: {'play': id},
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': 'https://animevost.org/'},
        ),
      );
      final urls = _extractMp4Urls(response.data ?? '');
      if (urls.isNotEmpty) return _pickBestUrl(urls);
    } catch (_) {}

    // getlink.php is a lighter fallback (one or two mirror URLs).
    try {
      final response = await _dio.get<String>(
        '/getlink.php',
        queryParameters: {'id': id},
        options: Options(responseType: ResponseType.plain),
      );
      final urls = _extractMp4Urls(response.data ?? '');
      if (urls.isNotEmpty) return _pickBestUrl(urls);
    } catch (_) {}
    return null;
  }

  List<String> _extractMp4Urls(String source) {
    final matches = RegExp(r'''https?://[^\s"'<>]+?\.mp4[^\s"'<>]*''')
        .allMatches(source);
    final seen = <String>{};
    final urls = <String>[];
    for (final match in matches) {
      final value = match
          .group(0)
          ?.replaceAll('&amp;', '&')
          .replaceAll(r'\u0026', '&');
      if (value != null && value.isNotEmpty && seen.add(value)) urls.add(value);
    }
    return urls;
  }

  String _pickBestUrl(List<String> urls) {
    bool has(String value, String token) => value.toLowerCase().contains(token);
    for (final url in urls) {
      if (has(url, '/1080/') || has(url, '1080p')) return url;
    }
    for (final url in urls) {
      if (has(url, '/720/') || has(url, 'hd.')) return url;
    }
    for (final url in urls) {
      if (has(url, 'std.') || has(url, '/480/')) return url;
    }
    return urls.first;
  }
}

/// Parses the inline episode map from an AnimeVost release page.
///
/// The page embeds ids as `var data = {"1 серия":"1451327130",...};`.
/// Some releases include a trailing comma before the closing brace, which
/// is not valid JSON and must be removed before decoding.
List<SourceEpisode> parseAnimeVostEpisodes(String html) {
  final episodes = <SourceEpisode>[];
  try {
    final match = RegExp(
      r'var\s+data\s*=\s*(\{[\s\S]*?\})\s*;',
      multiLine: true,
    ).firstMatch(html);
    if (match == null) return episodes;

    final decoded = jsonDecode(
      match.group(1)!.replaceAll(RegExp(r',\s*}'), '}'),
    ) as Map<String, dynamic>;
    var fallbackOrdinal = 0;
    for (final entry in decoded.entries) {
      fallbackOrdinal++;
      final id = entry.value?.toString() ?? '';
      if (id.isEmpty) continue;
      final ordinal =
          int.tryParse(RegExp(r'\d+').firstMatch(entry.key)?.group(0) ?? '') ??
          fallbackOrdinal;
      episodes.add(
        SourceEpisode(
          externalId: id,
          ordinal: ordinal,
          title: entry.key,
          posterUrl: 'https://media.aniland.org/img/$id.jpg',
        ),
      );
    }
    episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
  } catch (_) {}
  return episodes;
}
