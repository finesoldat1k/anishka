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

/// AnimeVost source provider — uses api.animevost.org for episodes and voiceovers.
class AnimeVost implements SourceProvider {
  AnimeVost({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.animevost.org',
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
  String get displayName => 'animevost';

  @override
  String get id => 'animevost';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    try {
      final response = await _dio.get(
        '/anime/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      final data = response.data;
      if (data is! List) return const [];
      return data
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
    final queries = <String>[
      if (nameHint != null && nameHint.isNotEmpty) nameHint,
      'anime',
    ].where((q) => q.isNotEmpty).toList();

    for (final query in queries) {
      try {
        final response = await _dio.get(
          '/anime/search',
          queryParameters: {'q': query, 'limit': 10},
        );
        final data = response.data;
        if (data is! List) continue;
        for (final item in data.whereType<Map<String, dynamic>>()) {
          final animeId = _asInt(item['id']);
          if (animeId == null) continue;
          // Verify this is the right anime by checking details
          final details = await _getDetails(animeId);
          if (details != null && details.shikimoriId == shikimoriId) {
            return _buildSources(animeId, details);
          }
        }
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final animeId = _asInt(sourceId);
    if (animeId == null) return null;
    final details = await _getDetails(animeId);
    if (details == null) return null;
    final sources = await _buildSources(animeId, details);
    return sources.isNotEmpty ? sources.first : null;
  }

  Future<_AnimeVostDetails?> _getDetails(int animeId) async {
    try {
      final response = await _dio.get('/anime/$animeId');
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      return _AnimeVostDetails.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<UnifiedSource>> _buildSources(
    int animeId,
    _AnimeVostDetails details,
  ) async {
    final sources = <UnifiedSource>[];
    final voiceovers = details.voiceovers ?? const [];

    for (final vo in voiceovers) {
      final studio = (vo['studio'] as String? ?? '').trim();
      if (studio.isEmpty) continue;

      final episodes = <UnifiedEpisode>[];
      final voEpisodes = vo['episodes'] as List? ?? const [];

      for (final ep in voEpisodes.whereType<Map<String, dynamic>>()) {
        final ordinal = _asInt(ep['number']) ?? _asInt(ep['episode']);
        if (ordinal == null || ordinal <= 0) continue;

        final hlsUrl = (ep['hls'] as String? ?? '').trim();
        final mp4Url = (ep['mp4'] as String? ?? '').trim();
        final embedUrl = (ep['iframe'] as String? ?? '').trim();

        final hls480 = _extractQuality(hlsUrl, '480') ?? _extractQuality(mp4Url, '480');
        final hls720 = _extractQuality(hlsUrl, '720') ?? _extractQuality(mp4Url, '720');
        final hls1080 = _extractQuality(hlsUrl, '1080') ?? _extractQuality(mp4Url, '1080');

        episodes.add(
          UnifiedEpisode(
            id: '${animeId}_${vo['id']}_$ordinal',
            ordinal: ordinal,
            title: (ep['title'] as String? ?? '').trim().isEmpty
                ? 'Серия $ordinal'
                : (ep['title'] as String? ?? '').trim(),
            hls480: hls480,
            hls720: hls720,
            hls1080: hls1080,
            embedUrl: embedUrl.isNotEmpty ? embedUrl : null,
            embedLabel: studio,
            duration: _asInt(ep['duration']),
          ),
        );
      }

      if (episodes.isNotEmpty) {
        episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
        sources.add(
          UnifiedSource(
            id: '${animeId}_${vo['id']}',
            providerId: 'animevost',
            title: studio,
            subtitle: 'озвучка · animevost',
            logoUrl: null,
            episodeCount: episodes.length,
            episodes: episodes,
            hasDirectStreams: episodes.any((e) => e.hasDirectStream),
            requiresResolution: false,
          ),
        );
      }
    }
    return sources;
  }

  String? _extractQuality(String? url, String quality) {
    if (url == null) return null;
    // URLs might contain quality in path or query
    if (url.contains('$quality.mp4') || url.contains('$quality.m3u8')) return url;
    if (url.contains('quality=$quality')) return url;
    return null;
  }

  UnifiedSource? _animeToSource(Map<String, dynamic> item) {
    final animeId = _asInt(item['id']);
    final title = (item['title'] as String? ?? '').trim();
    final poster = (item['poster'] as String? ?? '').trim();
    if (animeId == null || title.isEmpty) return null;
    return UnifiedSource(
      id: animeId.toString(),
      providerId: 'animevost',
      title: title,
      subtitle: 'animevost.org',
      logoUrl: poster.isNotEmpty ? poster : null,
      episodeCount: _asInt(item['episodes']) ?? 0,
      episodes: const [],
      hasDirectStreams: false,
      requiresResolution: true,
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}

class _AnimeVostDetails {
  final int id;
  final String title;
  final int? shikimoriId;
  final List<dynamic> voiceovers;

  _AnimeVostDetails({
    required this.id,
    required this.title,
    this.shikimoriId,
    required this.voiceovers,
  });

  factory _AnimeVostDetails.fromJson(Map<String, dynamic> json) {
    return _AnimeVostDetails(
      id: json['id'] as int? ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      shikimoriId: _asInt(json['shikimori_id']),
      voiceovers: json['voiceovers'] as List? ?? const [],
    );
  }
}