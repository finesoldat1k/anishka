import 'package:dio/dio.dart';

import '../resolved_stream.dart';
import 'embed_http.dart';
import 'embed_resolver.dart';

/// Resolves Sibnet embeds (`video.sibnet.ru/shell.php?...`) into MP4.
class SibnetResolver implements EmbedResolver {
  SibnetResolver({Dio? dio}) : _dio = dio ?? createEmbedDio();

  final Dio _dio;

  @override
  String get id => 'sibnet';

  @override
  bool canResolve(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('sibnet');
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
          headers: {'Referer': url},
        ),
      );
      final body = response.data ?? '';
      if (body.isEmpty) return null;

      final path = parseVideoPath(body);
      if (path == null) return null;
      final absolute = absoluteUrl(path, base: 'https://video.sibnet.ru');
      if (absolute == null) return null;

      return ResolvedStream(
        url: absolute,
        kind: StreamKind.mp4,
        headers: {'Referer': url},
      );
    } catch (_) {
      return null;
    }
  }

  /// Extract the `/v/....mp4` path from a Sibnet player page.
  ///
  /// Exposed for tests.
  static String? parseVideoPath(String html) {
    final patterns = [
      RegExp(r'''["'](\/v\/[^"']+?\.mp4)["']'''),
      RegExp(r'''(?:src|file)\s*[:=]\s*["']([^"']+?\.mp4)["']'''),
      RegExp(r'''["'](\/v\/[^"']+)["']'''),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        final value = match.group(1)!;
        if (value.startsWith('/v/')) return value;
      }
    }
    return null;
  }
}
