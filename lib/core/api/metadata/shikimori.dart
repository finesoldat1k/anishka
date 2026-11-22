// Shikimori client — primary metadata provider.
import 'dart:async';

import 'package:dio/dio.dart';

import '../../models/shikimori_anime.dart';
import '../exceptions.dart';
import '../shikimori_config.dart';
import 'metadata_provider.dart';
import 'unified_metadata.dart';

class Shikimori implements MetadataProvider {
  Shikimori({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                baseUrl: ShikimoriConfig.apiBase,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent': 'anishka/1.0',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  @override
  String get displayName => 'shikimori';

  @override
  String get id => 'shikimori';

  @override
  Future<List<UnifiedMetadata>> search({
    required String query,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/animes',
        queryParameters: {'search': query, 'limit': limit, 'order': 'popularity'},
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _toUnifiedFromCompact(
              ShikimoriAnime.fromJson(e as Map<String, dynamic>)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<UnifiedMetadata?> getDetails(int shikimoriId) async {
    try {
      final response = await _dio.get('/animes/$shikimoriId');
      final details = ShikimoriAnimeDetails.fromJson(
        response.data as Map<String, dynamic>,
      );
      return _toUnifiedFromDetails(details);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<String>> getScreenshots(int shikimoriId) async {
    try {
      final response = await _dio.get('/animes/$shikimoriId/screenshots');
      final list = response.data as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => ShikimoriConfig.imageUrl(item['original'] as String?))
          .whereType<String>()
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<List<UnifiedMetadata>> getRelatedByFranchise(
    String franchise, {
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/animes',
        queryParameters: {
          'franchise': franchise,
          'limit': limit,
          'order': 'popularity',
        },
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _toUnifiedFromCompact(
              ShikimoriAnime.fromJson(e as Map<String, dynamic>)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Get popular/ongoing anime for home page.
  Future<List<UnifiedMetadata>> getPopular({
    int limit = 50,
    String order = 'popularity',
    String? status,
    String? kind,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit, 'order': order};
      if (status != null) queryParams['status'] = status;
      if (kind != null) queryParams['kind'] = kind;

      final response = await _dio.get('/animes', queryParameters: queryParams);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => _toUnifiedFromCompact(
              ShikimoriAnime.fromJson(e as Map<String, dynamic>)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  UnifiedMetadata _toUnifiedFromCompact(ShikimoriAnime anime) => UnifiedMetadata(
    id: anime.id,
    shikimoriId: anime.id,
    title: anime.displayTitle,
    englishTitle: null,
    japaneseTitle: null,
    synopsis: null,
    description: null,
    score: double.tryParse(anime.score),
    year: anime.year,
    episodes: anime.episodes,
    duration: null,
    status: anime.status,
    kind: anime.kind,
    genres: const [],
    studios: const [],
    posterUrl: anime.posterOriginalUrl ?? anime.posterUrl,
    backgroundUrl: anime.backgroundUrl,
    trailerUrl: null,
    trailerThumbnail: null,
    trailerSite: null,
    screenshots: const [],
    ageRating: null,
    franchise: null,
  );

  UnifiedMetadata _toUnifiedFromDetails(ShikimoriAnimeDetails anime) => UnifiedMetadata(
    id: anime.id,
    shikimoriId: anime.id,
    title: anime.russian.isNotEmpty ? anime.russian : anime.name,
    englishTitle: anime.english?.isNotEmpty == true ? anime.english!.first : null,
    japaneseTitle: anime.japanese?.isNotEmpty == true ? anime.japanese!.first : null,
    synopsis: null,
    description: anime.descriptionText,
    score: anime.scoreValue,
    year: anime.year,
    episodes: anime.episodes,
    duration: anime.duration,
    status: anime.status,
    kind: anime.kind,
    genres: anime.allGenres,
    studios: anime.allStudios,
    posterUrl: anime.posterOriginalUrl ?? anime.posterUrl,
    backgroundUrl: anime.backgroundUrl ?? anime.metadataBackground,
    trailerUrl: anime.trailerUrl,
    trailerThumbnail: anime.trailerThumbnail,
    trailerSite: anime.trailerSite,
    screenshots: anime.screenshots,
    ageRating: anime.rating,
    franchise: anime.franchise,
  );
}