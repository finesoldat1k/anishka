import 'dart:convert';

import 'package:dio/dio.dart';

import '../resolved_stream.dart';
import 'embed_http.dart';
import 'embed_resolver.dart';

/// Resolves Aksor (`player.aksor.tv/video/{id}`) into MP4.
class AksorResolver implements EmbedResolver {
  AksorResolver({Dio? dio}) : _dio = dio ?? createEmbedDio();

  final Dio _dio;

  static const _qualityKeys = <String, int>{
    'q1080': 1080,
    'q720': 720,
    'q480': 480,
    'q360': 360,
    'q2k': 2048,
    'q4k': 4096,
  };

  @override
  String get id => 'aksor';

  @override
  bool canResolve(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('aksor');
  }

  @override
  Future<ResolvedStream?> resolve(
    String url, {
    String quality = 'auto',
  }) async {
    final videoId = parseVideoId(url);
    if (videoId == null) return null;
    try {
      final response = await _dio.get<String>(
        'https://player.aksor.tv/api/video/$videoId',
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'Accept': 'application/json',
            'Referer': 'https://old.yummyani.me/',
          },
        ),
      );
      final body = response.data ?? '';
      if (!body.trimLeft().startsWith('{')) return null;
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final qualities = decoded['qualities'];
      if (qualities is! Map) return null;

      final urls = <String, String>{};
      for (final entry in qualities.entries) {
        final key = entry.key.toString();
        final value = entry.value?.toString() ?? '';
        if (value.isEmpty || !_qualityKeys.containsKey(key)) continue;
        urls['${_qualityKeys[key]}'] = value;
      }
      if (urls.isEmpty) return null;

      final key = pickQuality(urls.keys, requested: quality);
      if (key == null) return null;
      final streamUrl = urls[key]!;
      return ResolvedStream(
        url: streamUrl,
        kind: StreamKind.fromUrl(streamUrl),
        headers: const {'Referer': 'https://old.yummyani.me/'},
        quality: key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Extract the numeric video id from an Aksor player URL.
  static String? parseVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final last = segments.last;
    if (RegExp(r'^\d+$').hasMatch(last)) return last;
    final match = RegExp(r'(\d+)').firstMatch(last);
    return match?.group(1);
  }
}
