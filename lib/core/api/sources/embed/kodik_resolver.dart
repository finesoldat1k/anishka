import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../resolved_stream.dart';
import 'embed_http.dart';
import 'embed_resolver.dart';

/// Resolves Kodik/Anivod/Aniqit player pages into direct HLS streams.
///
/// Flow (ported from `anicli-api`):
/// 1. GET the embed page and scrape `domain/d_sign/pd/.../vInfo`.
/// 2. GET the player JS and read the base64-encoded API endpoint from `atob`.
/// 3. POST the payload to that endpoint; links are ROT-18 + base64 encoded.
class KodikResolver implements EmbedResolver {
  KodikResolver({Dio? dio}) : _dio = dio ?? createEmbedDio();

  final Dio _dio;

  /// API path is global for a Kodik host and changes rarely.
  static final Map<String, String> _apiPaths = {};

  static const _apiPayloadConsts = {
    'bad_user': 'false',
    'info': '{}',
    'cdn_is_working': 'true',
  };

  @override
  String get id => 'kodik';

  @override
  bool canResolve(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('kodik') ||
        host.contains('anivod') ||
        host.contains('aniqit');
  }

  @override
  Future<ResolvedStream?> resolve(
    String url, {
    String quality = 'auto',
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    final netloc = uri.host;

    try {
      final page = await _getPage(url);
      if (page == null) return null;
      if (page.contains('Видео не найдено') ||
          page.contains('Видео запрещено к просмотру')) {
        return null;
      }

      final payload = _parsePayload(page);
      if (payload == null) return null;

      final jsPath = _parsePlayerJsPath(page);
      var apiPath = _apiPaths[netloc];
      if (apiPath == null && jsPath != null) {
        apiPath = await _fetchApiPath(netloc, jsPath);
      }
      apiPath ??= '/ftor';

      var response = await _postApi(netloc, apiPath, url, payload);
      if (response == null) {
        // The API endpoint expired: refresh it from the player JS and retry.
        if (jsPath != null) {
          final refreshed = await _fetchApiPath(netloc, jsPath);
          if (refreshed != null && refreshed != apiPath) {
            _apiPaths[netloc] = refreshed;
            response = await _postApi(netloc, refreshed, url, payload);
          }
        }
      }
      if (response == null) return null;

      final links = response['links'];
      if (links is! Map) return null;
      final streams = parseLinks(links.cast<dynamic, dynamic>());
      if (streams.isEmpty) return null;

      final key = pickQuality(streams.keys, requested: quality);
      if (key == null) return null;
      final stream = streams[key]!;
      return stream.copyWith(quality: key, variants: streams);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getPage(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'Referer': 'https://kodik.info/'},
      ),
    );
    if (response.statusCode == null || response.statusCode! >= 400) {
      return null;
    }
    return response.data;
  }

  Map<String, String>? _parsePayload(String page) {
    String? value(RegExp pattern) => firstMatch(pattern, page);

    final payload = <String, String>{
      'd': value(RegExp(r'''var\s*domain\s*=\s*['"](.*?)['"];''')) ?? '',
      'd_sign': value(RegExp(r'''var\s*d_sign\s*=\s*['"](.*?)['"];''')) ?? '',
      'pd': value(RegExp(r'''var\s*pd\s*=\s*['"](.*?)['"];''')) ?? '',
      'pd_sign': value(RegExp(r'''var\s*pd_sign\s*=\s*['"](.*?)['"];''')) ?? '',
      'ref': value(RegExp(r'''var\s*ref\s*=\s*['"](.*?)['"];''')) ?? '',
      'ref_sign': value(RegExp(r'''var\s*ref_sign\s*=\s*['"](.*?)['"];''')) ?? '',
      'type': value(RegExp(r'''vInfo\.type = ['"](.*?)['"];''')) ?? '',
      'hash': value(RegExp(r'''vInfo\.hash = ['"](.*?)['"];''')) ?? '',
      'id': value(RegExp(r'''vInfo\.id = ['"](.*?)['"];''')) ?? '',
    };
    if (payload['type']!.isEmpty ||
        payload['hash']!.isEmpty ||
        payload['id']!.isEmpty) {
      return null;
    }
    return payload;
  }

  String? _parsePlayerJsPath(String page) {
    try {
      final document = html_parser.parse(page);
      for (final script in document.querySelectorAll('head script[src]')) {
        final src = script.attributes['src'] ?? '';
        if (src.contains('assets/js')) return src;
      }
      for (final script in document.querySelectorAll('script[src]')) {
        final src = script.attributes['src'] ?? '';
        if (src.contains('assets/js')) return src;
      }
    } catch (_) {
      // Fall through to regex.
    }
    return firstMatch(
      RegExp(r'''<script[^>]+src=["']([^"']*assets/js[^"']*)["']'''),
      page,
    );
  }

  Future<String?> _fetchApiPath(String netloc, String jsPath) async {
    try {
      final jsUrl = jsPath.startsWith('http')
          ? jsPath
          : 'https://$netloc${jsPath.startsWith('/') ? '' : '/'}$jsPath';
      final response = await _dio.get<String>(
        jsUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data ?? '';
      final encoded = firstMatch(
        RegExp(r'''\$\.ajax[^)]+atob\(["'](\w+=)["']\)'''),
        body,
      );
      if (encoded == null) return null;
      var padded = encoded;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final decoded = utf8.decode(base64.decode(padded)).trim();
      if (decoded.isEmpty) return null;
      final path = decoded.startsWith('/') ? decoded : '/$decoded';
      _apiPaths[netloc] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _postApi(
    String netloc,
    String apiPath,
    String referer,
    Map<String, String> payload,
  ) async {
    try {
      final response = await _dio.post<String>(
        'https://$netloc${apiPath.startsWith('/') ? '' : '/'}$apiPath',
        data: {...payload, ..._apiPayloadConsts},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          headers: {
            'Origin': 'https://$netloc',
            'Referer': referer,
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
      if (response.statusCode == null || response.statusCode! >= 400) {
        return null;
      }
      final body = response.data ?? '';
      if (!body.trimLeft().startsWith('{')) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Decode the `links` map returned by the Kodik API.
  ///
  /// Exposed for tests; quality keys map to playable HLS/MP4 URLs.
  static Map<String, ResolvedStream> parseLinks(
    Map<dynamic, dynamic> links,
  ) {
    final result = <String, ResolvedStream>{};
    for (final entry in links.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! List || value.isEmpty) continue;
      final first = value.first;
      if (first is! Map) continue;
      final raw = first['src']?.toString() ?? '';
      final url = decodeKodikUrl(raw);
      if (url == null) continue;
      // Kodik's `720` bucket occasionally contains a 480p file.
      final fixed = key == '720' ? url.replaceAll('/480.mp4:', '/720.mp4:') : url;
      result[key] = ResolvedStream(
        url: fixed,
        kind: StreamKind.fromUrl(fixed),
        headers: const {
          'Referer': 'https://kodik.info/',
          'Origin': 'https://kodik.info',
        },
        quality: key,
      );
    }
    return result;
  }
}
