import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../resolved_stream.dart';
import 'embed_http.dart';
import 'embed_resolver.dart';

/// Resolves Aniboom embeds (`aniboom.one/embed/...`) into HLS/DASH.
class AniboomResolver implements EmbedResolver {
  AniboomResolver({Dio? dio}) : _dio = dio ?? createEmbedDio();

  final Dio _dio;

  static const _playbackHeaders = {
    'Referer': 'https://aniboom.one/',
    'Accept-Language': 'ru-RU',
    'Origin': 'https://aniboom.one',
  };

  @override
  String get id => 'aniboom';

  @override
  bool canResolve(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('aniboom');
  }

  @override
  Future<ResolvedStream?> resolve(
    String url, {
    String quality = 'auto',
  }) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Referer': 'https://animego.me/',
          },
        ),
      );
      final body = response.data ?? '';
      if (body.isEmpty) return null;

      final document = html_parser.parse(body);
      final raw = document.querySelector('#video')?.attributes['data-parameters'];
      if (raw == null || raw.isEmpty) return null;

      final params = parseParameters(raw);
      if (params == null) return null;

      final hls = _nestedSrc(params['hls']);
      final dash = _nestedSrc(params['dash']);
      final source = hls ?? dash;
      if (source == null || source.isEmpty) return null;

      final absolute = absoluteUrl(source, base: url);
      if (absolute == null) return null;

      final qualityValue = params['qualityVideo'];
      return ResolvedStream(
        url: absolute,
        kind: StreamKind.fromUrl(absolute),
        headers: _playbackHeaders,
        quality: qualityValue?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse the `data-parameters` attribute of an Aniboom player.
  ///
  /// Exposed for tests: accepts both raw JSON and HTML-escaped JSON.
  static Map<String, dynamic>? parseParameters(String raw) {
    final value = unescapeHtml(raw).trim();
    if (value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {
      // Some pages store the payload as a quoted JSON string.
      try {
        final decoded = jsonDecode(value.replaceAll(r'\"', '"'));
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _nestedSrc(Object? value) {
    if (value == null) return null;
    if (value is Map) {
      return value['src']?.toString();
    }
    if (value is String) {
      final text = unescapeHtml(value.replaceAll(r'\/', '/')).trim();
      if (text.isEmpty) return null;
      if (text.startsWith('{')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) return decoded['src']?.toString();
        } catch (_) {
          return null;
        }
      }
      final match = RegExp(r'https?://[^"\s]+').firstMatch(text);
      return match?.group(0);
    }
    return null;
  }
}
