import 'dart:async';

import 'package:dio/dio.dart';

import 'source_provider.dart';
import 'unified_source.dart';

/// Helper to safely parse int from dynamic values.
int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

/// Anilib Me source provider — uses animelib.org API.
class AnilibMe implements SourceProvider {
  AnilibMe({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://animelib.org',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'anishka/1.0',
                },
              ),
            );

  final Dio _dio;

  @override
  String get displayName => 'anilibme';

  @override
  String get id => 'anilibme';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    try {
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      final data = response.data;
      if (data is! Map) return const [];
      final results = data['data'] as List? ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(_animeToSource)
          .where((s) => s != null)
          .cast<UnifiedSource>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    // TODO: Implement shikimori_id lookup if API supports it
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    try {
      final response = await _dio.get('/api/v1/anime/$sourceId');
      final data = response.data;
      if (data is! Map) return null;
      final anime = data['data'] as Map<String, dynamic>?;
      if (anime == null) return null;
      return _buildSource(anime);
    } catch (_) {
      return null;
    }
  }

  UnifiedSource? _animeToSource(Map<String, dynamic> item) {
    final id = (item['slug'] as String? ?? item['id'] as String? ?? '').trim();
    final title = (item['title'] as String? ?? '').trim();
    final poster = (item['poster'] as String? ?? '').trim();
    if (id.isEmpty || title.isEmpty) return null;
    return UnifiedSource(
      id: id,
      providerId: 'anilibme',
      title: title,
      subtitle: 'AnimeLib',
      logoUrl: poster.isNotEmpty ? poster : null,
      episodeCount: _asInt(item['episodes_count']) ?? 0,
      episodes: const [],
      hasDirectStreams: false,
      requiresResolution: true,
    );
  }

  UnifiedSource? _buildSource(Map<String, dynamic> anime) {
    final id = (anime['slug'] as String? ?? anime['id'] as String? ?? '').trim();
    final title = (anime['title'] as String? ?? '').trim();
    final poster = (anime['poster'] as String? ?? '').trim();
    final episodesData = anime['episodes'] as List? ?? const [];

    final episodes = <UnifiedEpisode>[];
    for (final ep in episodesData.whereType<Map<String, dynamic>>()) {
      final ordinal = _asInt(ep['number']) ?? _asInt(ep['episode']);
      if (ordinal == null || ordinal <= 0) continue;

      final hlsUrl = (ep['hls_url'] as String? ?? '').trim();
      final mp4Url = (ep['mp4_url'] as String? ?? '').trim();

      episodes.add(
        UnifiedEpisode(
          id: '${id}_$ordinal',
          ordinal: ordinal,
          title: (ep['title'] as String? ?? '').trim().isEmpty
              ? 'Серия $ordinal'
              : (ep['title'] as String? ?? '').trim(),
          hls480: _extractQuality(hlsUrl, '480') ?? _extractQuality(mp4Url, '480'),
          hls720: _extractQuality(hlsUrl, '720') ?? _extractQuality(mp4Url, '720'),
          hls1080: _extractQuality(hlsUrl, '1080') ?? _extractQuality(mp4Url, '1080'),
          duration: _asInt(ep['duration']),
        ),
      );
    }

    if (episodes.isEmpty) return null;

    episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return UnifiedSource(
      id: id,
      providerId: 'anilibme',
      title: title,
      subtitle: 'AnimeLib',
      logoUrl: poster.isNotEmpty ? poster : null,
      episodeCount: episodes.length,
      episodes: episodes,
      hasDirectStreams: episodes.any((e) => e.hasDirectStream),
      requiresResolution: false,
    );
  }

  String? _extractQuality(String? url, String quality) {
    if (url == null) return null;
    if (url.contains('$quality.mp4') || url.contains('$quality.m3u8')) return url;
    if (url.contains('quality=$quality')) return url;
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}