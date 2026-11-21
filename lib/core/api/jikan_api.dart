/// Jikan API (MyAnimeList) client for anime metadata.
///
/// Jikan is a public, unofficial REST API for MyAnimeList with no auth required.
/// We use it as a fallback for titles, descriptions, studios, genres, and images.
library;

import 'dart:async';

import 'package:dio/dio.dart';

import '../models/jikan_models.dart';

class JikanApi {
  JikanApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.jikan.moe/v4',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'User-Agent': 'anishka/1.0 (https://github.com/anishka; +https://anishka.app)',
                'Accept': 'application/json',
              },
            ),
          );

  final Dio _dio;

  /// Search anime by query. Returns up to [limit] results.
  Future<List<JikanAnime>> search(String query, {int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/anime',
        queryParameters: {
          'q': query,
          'limit': limit.clamp(1, 25),
          'order_by': 'popularity',
          'sort': 'desc',
        },
      );
      final data = response.data;
      if (data is! Map) return const [];
      final list =
          (data['data'] as List?)
              ?.map((e) => JikanAnime.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [];
      return list;
    } on DioException catch (_) {
      return const [];
    }
  }

  /// Get full anime details by MyAnimeList ID.
  Future<JikanAnimeDetails?> getDetails(int malId) async {
    try {
      final response = await _dio.get('/anime/$malId/full');
      final data = response.data;
      if (data is! Map) return null;
      return JikanAnimeDetails.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (_) {
      return null;
    }
  }

  /// Get anime details by searching for the title first.
  Future<JikanAnimeDetails?> findByTitle(String title) async {
    final results = await search(title, limit: 3);
    if (results.isEmpty) return null;
    // Try exact match first
    for (final anime in results) {
      if (anime.title.toLowerCase() == title.toLowerCase() ||
          anime.titleEnglish?.toLowerCase() == title.toLowerCase() ||
          anime.titleJapanese?.toLowerCase() == title.toLowerCase()) {
        return await getDetails(anime.malId);
      }
    }
    // Fall back to first result
    return await getDetails(results.first.malId);
  }
}
