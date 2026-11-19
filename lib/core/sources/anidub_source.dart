// AniDub video source: DLE search and Sibnet-backed episodes.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/models/video_source.dart';

class AniDubVideoSource implements VideoSource {
  AniDubVideoSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://anidub.com',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                      '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'Accept-Language': 'ru,en;q=0.8',
                },
              ),
            );

  final Dio _dio;
  final Map<String, String?> _streamCache = {};

  @override
  String get sourceId => 'anidub';

  @override
  String get displayName => 'anidub';

  @override
  int get priority => 3;

  @override
  List<String> get availableQualities => const ['auto'];

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
      final items = document.querySelectorAll('.th-item');
      for (final item in items.take(limit)) {
        final link = item.querySelector('a.th-in');
        final href = link?.attributes['href'];
        if (link == null || href == null || href.isEmpty) continue;

        final rawTitle = item.querySelector('.th-title')?.text.trim() ??
            link.text.trim();
        final subtitle = item.querySelector('.th-subtitle')?.text.trim();
        final yearText = item
            .querySelectorAll('.th-subtitle')
            .map((node) => node.text)
            .join(' ');
        final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(yearText);
        final rating = item.querySelector('.th-rating')?.text.trim();
        final img = item.querySelector('.th-img img, img');
        final poster = img?.attributes['src'] ?? img?.attributes['data-src'];

        results.add(
          SourceAnimeEntry(
            sourceId: sourceId,
            externalId: _absoluteUrl(href),
            title: rawTitle,
            russianTitle: _cleanTitle(rawTitle),
            posterUrl: poster == null ? null : _resolveUrl(poster),
            year: yearMatch == null ? null : int.tryParse(yearMatch.group(0)!),
            kind: subtitle,
            status: null,
            episodes: null,
            score: rating,
          ),
        );
      }
    } catch (_) {}
    return results;
  }

  String _cleanTitle(String raw) {
    var title = raw;
    final slash = title.indexOf(' / ');
    if (slash > 0) title = title.substring(0, slash);
    title = title.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    return title;
  }

  String _absoluteUrl(String href) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('//')) return 'https:$href';
    return 'https://anidub.com${href.startsWith('/') ? '' : '/'}$href';
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return 'https://anidub.com${url.startsWith('/') ? '' : '/'}$url';
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
      final rawTitle = (ogTitle ?? heading ?? '').trim();
      final russianTitle = _cleanTitle(
        rawTitle.replaceAll('Смотреть', '').replaceAll('онлайн', '').trim(),
      );

      final ogImage = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
      final poster = ogImage ?? document.querySelector('.fposter img, img')?.attributes['src'];

      final description = document.querySelector('.fdesc')?.text.trim() ??
          document
              .querySelector('meta[property="og:description"]')
              ?.attributes['content']
              ?.trim();

      final year = int.tryParse(
        RegExp(r'Год выхода:\s*(\d{4})').firstMatch(pageText)?.group(1) ??
            RegExp(r'\b(19|20)\d{2}\b').firstMatch(pageText)?.group(0) ??
            '',
      );
      final kind = RegExp(r'Тип:\s*([^\n]+)')
          .firstMatch(pageText)
          ?.group(1)
          ?.trim();

      final episodes = _parseEpisodes(document);

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
        score: null,
        genres: _parseGenres(pageText),
        episodesList: episodes,
      );
    } catch (_) {
      return null;
    }
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

  List<SourceEpisode> _parseEpisodes(dynamic document) {
    final episodes = <SourceEpisode>[];
    try {
      final spans = document.querySelectorAll('.tabs-sel span[data]') as List;
      var fallbackOrdinal = 0;
      for (final span in spans) {
        fallbackOrdinal++;
        final data = span.attributes['data'] as String?;
        if (data == null || data.isEmpty) continue;
        final label = span.text.trim();
        final ordinal = int.tryParse(
              RegExp(r'\d+').firstMatch(label)?.group(0) ?? '',
            ) ??
            fallbackOrdinal;
        final sibnetId = RegExp(r'videoid=(\d+)').firstMatch(data)?.group(1);
        if (sibnetId == null) continue;
        episodes.add(
          SourceEpisode(
            externalId: sibnetId,
            ordinal: ordinal,
            title: label,
          ),
        );
      }
      episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    } catch (_) {}
    return episodes;
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

    final url = await _resolveSibnet(id);
    _streamCache[id] = url;
    return url;
  }

  Future<String?> _resolveSibnet(String videoId) async {
    final candidates = [
      'https://video.sibnet.ru/shell.php?videoid=$videoId',
      'https://video.sibnet.ru/shell.php?videoid=$videoId&player=1',
      'https://video.sibnet.ru/video$videoId/',
    ];
    for (final url in candidates) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'Referer': 'https://anidub.com/',
              'Origin': 'https://anidub.com',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ),
        );
        final urls = _extractVideoUrls(response.data ?? '');
        if (urls.isNotEmpty) return urls.first;
      } catch (_) {}
    }
    return null;
  }

  List<String> _extractVideoUrls(String source) {
    final matches = RegExp(
      r'''https?:[^\s"'<>]+?\.(?:mp4|m3u8)[^\s"'<>]*''',
    ).allMatches(source);
    final seen = <String>{};
    final urls = <String>[];
    for (final match in matches) {
      final value = match.group(0)
          ?.replaceAll('&amp;', '&')
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\/', '/');
      if (value != null && value.isNotEmpty && seen.add(value)) urls.add(value);
    }
    return urls;
  }
}
