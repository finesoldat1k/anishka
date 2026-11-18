// AniDub video source implementation (RSS + HTML parsing).
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
                headers: {
                  'User-Agent': 'anishka/1.0',
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                },
              ),
            );

  final Dio _dio;

  @override
  String get sourceId => 'anidub';

  @override
  String get displayName => 'AniDub';

  @override
  int get priority => 3; // Third priority

  @override
  List<String> get availableQualities => const ['1080', '720', '480'];

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
    try {
      final response = await _dio.get(
        '/index.php',
        queryParameters: {
          'do': 'search',
          'subaction': 'search',
          'q': query,
        },
      );
      return _parseSearchResults(response.data, limit);
    } catch (_) {
      return const [];
    }
  }

  List<SourceAnimeEntry> _parseSearchResults(String html, int limit) {
    final results = <SourceAnimeEntry>[];
    try {
      final document = html_parser.parse(html);
      final items = document.querySelectorAll('.shortstory, .news-item, .article, [class*="story"]');
      
      for (final item in items.take(limit)) {
        final titleEl = item.querySelector('h2 a, h3 a, .title a, a[href*="/anime/"]');
        final linkEl = item.querySelector('a[href*="/anime/"]');
        final imgEl = item.querySelector('img');
        
        if (titleEl == null || linkEl == null) continue;
        
        final href = linkEl.attributes['href'];
        if (href == null) continue;
        
        final externalId = _extractId(href);
        if (externalId.isEmpty) continue;
        
        final title = titleEl.text.trim();
        final posterUrl = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'];
        
        results.add(SourceAnimeEntry(
          sourceId: sourceId,
          externalId: externalId,
          title: title,
          russianTitle: title,
          posterUrl: (posterUrl?.isNotEmpty ?? false) ? _resolveUrl(posterUrl!) : null,
        ));
      }
    } catch (_) {}
    return results;
  }

  String _extractId(String href) {
    final matches = RegExp(r'/(\d+)[-/]').firstMatch(href);
    return matches?.group(1) ?? '';
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return 'https://anidub.com$url';
  }

  @override
  Future<SourceAnimeDetails?> getDetails(String externalId) async {
    try {
      final response = await _dio.get('/anime/$externalId.html');
      return _parseDetails(externalId, response.data);
    } catch (_) {
      return null;
    }
  }

  SourceAnimeDetails? _parseDetails(String externalId, String html) {
    try {
      final document = html_parser.parse(html);
      
      final titleEl = document.querySelector('h1, .title, .news-title');
      final title = titleEl?.text.trim() ?? '';
      
      final descEl = document.querySelector('.full-text, .description, .story-content, [class*="description"]');
      final description = descEl?.text.trim();
      
      final imgEl = document.querySelector('.poster img, .poster-image img, .news-image img');
      final posterUrl = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'];
      
      String? year;
      String? kind;
      String? status;
      
      final infoBlocks = document.querySelectorAll('.info-block, .anime-info, [class*="info"] li, .short-info li');
      for (final block in infoBlocks) {
        final text = block.text.toLowerCase();
        if (text.contains('год') || text.contains('year')) {
          year = _extractValue(text);
        } else if (text.contains('тип') || text.contains('type')) {
          kind = _extractValue(text);
        } else if (text.contains('статус') || text.contains('status')) {
          status = _extractValue(text);
        }
      }
      
      final episodes = <SourceEpisode>[];
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final content = script.text;
        if (content.contains('playlist') || content.contains('episodes') || content.contains('series')) {
          final eps = _extractEpisodes(content);
          episodes.addAll(eps);
        }
      }
      
      final iframes = document.querySelectorAll('iframe[src*="player"], iframe[src*="video"]');
      for (final iframe in iframes) {
        final src = iframe.attributes['src'];
        if (src != null && src.isNotEmpty) {
          episodes.add(SourceEpisode(
            externalId: 'iframe_${episodes.length}',
            ordinal: episodes.length + 1,
            hlsUrls: {'auto': src},
          ));
        }
      }
      
      return SourceAnimeDetails(
        sourceId: sourceId,
        externalId: externalId,
        title: '',
        russianTitle: title,
        description: description,
        posterUrl: posterUrl != null ? 'https://anidub.com$posterUrl' : null,
        kind: kind,
        status: status,
        year: int.tryParse(year ?? ''),
        episodesList: episodes,
      );
    } catch (_) {
      return null;
    }
  }

  String _extractValue(String text) {
    final parts = text.split(':');
    if (parts.length > 1) return parts[1].trim();
    return text.trim();
  }

  List<SourceEpisode> _extractEpisodes(String jsContent) {
    final episodes = <SourceEpisode>[];
    try {
      final playlistMatches = RegExp(r'playlist\s*[:=]\s*(\[[\s\S]*?\])').allMatches(jsContent);
      for (final match in playlistMatches) {
        final listStr = match.group(1);
        if (listStr != null) {
          // Try to parse as JSON-like - find URLs in the content
          final urlMatches = RegExp(r'https?://[^\s<>]+\.(m3u8|mp4)').allMatches(listStr);
          int ord = 1;
          for (final urlMatch in urlMatches) {
            final url = urlMatch.group(0);
            if (url != null && url.isNotEmpty) {
              episodes.add(SourceEpisode(
                externalId: 'parsed_$ord',
                ordinal: ord++,
                hlsUrls: {'auto': url},
              ));
            }
          }
        }
      }
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
    return null;
  }
}