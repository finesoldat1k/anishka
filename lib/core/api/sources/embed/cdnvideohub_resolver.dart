import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../resolved_stream.dart';
import 'embed_http.dart';
import 'embed_resolver.dart';

/// Resolves AnimeGO/CDNVideoHub `cdn-iframe` embeds into MP4/HLS.
class CdnVideoHubResolver implements EmbedResolver {
  CdnVideoHubResolver({Dio? dio}) : _dio = dio ?? createEmbedDio();

  final Dio _dio;

  static const _apiBase = 'https://plapi.cdnvideohub.com/api/v1/player/sv';

  static const _qualityKeys = <String, int>{
    'mpegTinyUrl': 144,
    'mpegLowestUrl': 240,
    'mpegLowUrl': 360,
    'mpegMediumUrl': 480,
    'mpegHighUrl': 720,
    'mpegFullHdUrl': 1080,
    'mpegQhdUrl': 1440,
    'mpeg2kUrl': 2048,
    'mpeg4kUrl': 4096,
  };

  @override
  String get id => 'cdnvideohub';

  @override
  bool canResolve(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host.contains('cdnvideohub')) return true;
    if (!host.contains('animego')) return false;
    return uri.path.contains('cdn-iframe') || uri.path.contains('/cdn-');
  }

  @override
  Future<ResolvedStream?> resolve(
    String url, {
    String quality = 'auto',
  }) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      // Direct player API links already contain the vk id.
      final directMatch = RegExp(r'/video/([^/?#]+)').firstMatch(uri.path);
      if (uri.host.contains('plapi') && directMatch != null) {
        return await _resolveVkId(directMatch.group(1)!, quality);
      }

      final parts = parsePathParts(url);
      if (parts == null) return null;

      final page = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Referer': 'https://animego.me/'},
        ),
      );
      final body = page.data ?? '';
      if (body.isEmpty) return null;

      final params = parsePlayerParams(body);
      if (params == null) return null;

      final playlist = await _getJson(
        '$_apiBase/playlist',
        query: {
          'pub': params.publisherId,
          'aggr': params.aggregator,
          'id': params.titleId,
        },
      );
      if (playlist == null) return null;

      final items = playlist['items'];
      if (items is! List || items.isEmpty) return null;

      final season = int.tryParse(parts.season) ?? 0;
      final episode = int.tryParse(parts.episode) ?? 0;
      final dubber = parts.dubber.toLowerCase();

      Map<String, dynamic>? match;
      for (final item in items) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        if ((map['season'] as num?)?.toInt() != season) continue;
        if ((map['episode'] as num?)?.toInt() != episode) continue;
        final studio = (map['voiceStudio'] ?? '').toString().toLowerCase();
        if (studio == dubber) {
          match = map;
          break;
        }
        match ??= map;
      }
      final vkId = match?['vkId']?.toString();
      if (vkId == null || vkId.isEmpty) return null;

      return await _resolveVkId(vkId, quality);
    } catch (_) {
      return null;
    }
  }

  Future<ResolvedStream?> _resolveVkId(String vkId, String quality) async {
    final data = await _getJson('$_apiBase/video/$vkId');
    if (data == null) return null;
    final sources = data['sources'];
    if (sources is! Map) return null;

    final hls = sources['hlsUrl']?.toString();
    final dash = sources['dashUrl']?.toString();
    final mp4 = <String, String>{};
    for (final entry in sources.entries) {
      final key = entry.key.toString();
      final value = entry.value?.toString() ?? '';
      if (!_qualityKeys.containsKey(key) || value.isEmpty) continue;
      mp4['${_qualityKeys[key]}'] = value;
    }

    const headers = <String, String>{
      'User-Agent': embedUserAgent,
      'Referer': 'https://animego.me/',
    };

    if (quality == 'auto' && hls != null && hls.isNotEmpty) {
      return ResolvedStream(
        url: hls,
        kind: StreamKind.hls,
        headers: headers,
      );
    }
    if (mp4.isNotEmpty) {
      final key = pickQuality(mp4.keys, requested: quality);
      if (key != null) {
        final url = mp4[key]!;
        return ResolvedStream(
          url: url,
          kind: StreamKind.fromUrl(url),
          headers: headers,
          quality: key,
        );
      }
    }
    if (hls != null && hls.isNotEmpty) {
      return ResolvedStream(
        url: hls,
        kind: StreamKind.hls,
        headers: headers,
      );
    }
    if (dash != null && dash.isNotEmpty) {
      return ResolvedStream(
        url: dash,
        kind: StreamKind.dash,
        headers: headers,
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getJson(
    String url, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<String>(
        url,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'application/json, text/plain, */*'},
        ),
      );
      final body = response.data ?? '';
      if (!body.trimLeft().startsWith('{')) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Ignore.
    }
    return null;
  }

  /// Split `.../cdn-iframe/{id}/{dubber}/{season}/{episode}`.
  static ({String id, String dubber, String season, String episode})?
      parsePathParts(String url) {
    final index = url.indexOf('cdn-iframe/');
    if (index < 0) return null;
    final tail = url.substring(index + 'cdn-iframe/'.length);
    final clean = tail.split('?').first.split('#').first;
    final segments = clean.split('/').where((item) => item.isNotEmpty).toList();
    if (segments.length < 4) return null;
    return (
      id: segments[0],
      dubber: Uri.decodeComponent(segments[1].replaceAll('+', ' ')),
      season: segments[2],
      episode: segments[3],
    );
  }

  /// Read CDNVideoHub identifiers from a page containing `<video-player>`.
  ///
  /// Exposed for tests.
  static ({String titleId, String publisherId, String aggregator})?
      parsePlayerParams(String html) {
    String? attr(String name) {
      final pattern = RegExp(
        '<video-player[^>]*\\s$name=["\\\']([^"\\\']*)["\\\']',
        caseSensitive: false,
      );
      return pattern.firstMatch(html)?.group(1);
    }

    var titleId = attr('data-title-id');
    var publisherId = attr('data-publisher-id');
    var aggregator = attr('data-aggregator');

    if (titleId == null || publisherId == null) {
      try {
        final element = html_parser.parse(html).querySelector('video-player');
        if (element != null) {
          titleId ??= element.attributes['data-title-id'];
          publisherId ??= element.attributes['data-publisher-id'];
          aggregator ??= element.attributes['data-aggregator'] ??
              element.attributes['ident'];
        }
      } catch (_) {
        // Ignore parse errors.
      }
    }
    if (titleId == null ||
        titleId.isEmpty ||
        publisherId == null ||
        publisherId.isEmpty) {
      return null;
    }
    return (
      titleId: titleId,
      publisherId: publisherId,
      aggregator: aggregator ?? '',
    );
  }
}
