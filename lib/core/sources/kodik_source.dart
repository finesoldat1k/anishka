// Kodik video source (video hosting API).
import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/models/video_source.dart';

/// Kodik video hosting API source.
/// Requires API token from kodik.info
class KodikVideoSource implements VideoSource {
  KodikVideoSource({
    Dio? dio,
    required this.token,
    this.baseUrl = 'https://kodik.info/api',
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent': 'anishka/1.0',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;
  final String token;
  final String baseUrl;

  @override
  String get sourceId => 'kodik';

  @override
  String get displayName => 'Kodik';

  @override
  int get priority => 4; // Video hosting fallback

  @override
  List<String> get availableQualities => const ['1080', '720', '480'];

  @override
  Future<bool> healthCheck() async {
    try {
      await _dio.get('/search', queryParameters: {'token': token, 'limit': 1});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<SourceAnimeEntry>> search(String query, {int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'token': token,
          'title': query,
          'limit': limit,
          'with_episodes': true,
          'with_material_data': true,
        },
      );
      return _parseSearchResults(response.data, limit);
    } catch (_) {
      return const [];
    }
  }

  List<SourceAnimeEntry> _parseSearchResults(dynamic data, int limit) {
    final results = <SourceAnimeEntry>[];
    try {
      final list = data is List ? data : (data as Map?)?['results'] as List? ?? [];
      for (final item in list.take(limit)) {
        final map = item as Map<String, dynamic>;
        results.add(SourceAnimeEntry(
          sourceId: sourceId,
          externalId: map['id']?.toString() ?? '',
          title: map['title_orig'] ?? map['title'] ?? '',
          russianTitle: map['title'] ?? map['title_orig'],
          posterUrl: map['poster'] ?? map['poster_url'],
          year: map['year'],
          kind: map['type']?.toString().toLowerCase(),
          status: map['status'],
          episodes: map['episodes_count'] ?? map['episodes'],
          score: map['rating']?.toString(),
        ));
      }
    } catch (_) {}
    return results;
  }

  @override
  Future<SourceAnimeDetails?> getDetails(String externalId) async {
    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'token': token,
          'id': externalId,
          'with_episodes': true,
          'with_material_data': true,
        },
      );
      final list = response.data as List?;
      if (list == null || list.isEmpty) return null;
      return _mapDetails(list.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  SourceAnimeDetails _mapDetails(Map<String, dynamic> map) {
    final episodes = <SourceEpisode>[];
    final episodesData = map['episodes'] as List?;
    if (episodesData != null) {
      for (final ep in episodesData) {
        final epMap = ep as Map<String, dynamic>;
        final links = epMap['links'] as Map<String, dynamic>?;
        final hlsUrls = <String, String>{};
        if (links != null) {
          for (final entry in links.entries) {
            final quality = entry.key;
            final url = entry.value as String?;
            if (url != null && url.isNotEmpty) {
              hlsUrls[quality] = url;
            }
          }
        }
        episodes.add(SourceEpisode(
          externalId: epMap['id']?.toString() ?? '',
          ordinal: epMap['episode'] ?? 0,
          title: epMap['title'] as String?,
          hlsUrls: hlsUrls,
        ));
      }
    }

    return SourceAnimeDetails(
      sourceId: sourceId,
      externalId: map['id']?.toString() ?? '',
      title: map['title_orig'] ?? map['title'] ?? '',
      russianTitle: map['title'] ?? map['title_orig'],
      description: map['description'],
      posterUrl: map['poster'] ?? map['poster_url'],
      year: map['year'],
      kind: map['type']?.toString().toLowerCase(),
      status: map['status'],
      episodes: map['episodes_count'] ?? map['episodes'],
      score: map['rating']?.toString(),
      genres: (map['genres'] as List?)?.map((e) => e.toString()).toList(),
      episodesList: episodes,
    );
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String externalId) async {
    final details = await getDetails(externalId);
    return details?.episodesList ?? const [];
  }

  @override
  Future<String?> getStreamUrl(String sourceEpisodeId, String quality) async {
    // Kodik includes stream URLs in episode data
    return null;
  }
}