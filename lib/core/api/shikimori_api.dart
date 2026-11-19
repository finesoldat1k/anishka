// Shikimori API client.
import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api/exceptions.dart';
import '../../core/api/shikimori_config.dart';
import '../../core/models/shikimori_anime.dart';

class ShikimoriApi {
  ShikimoriApi({Dio? dio})
      : _dio = dio ??
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

  /// Search anime by query.
  Future<List<ShikimoriAnime>> search({
    required String query,
    int limit = 50,
    String order = 'popularity',
  }) async {
    try {
      final response = await _dio.get(
        '/animes',
        queryParameters: {
          'search': query,
          'limit': limit,
          'order': order,
        },
      );
      final list = response.data as List<dynamic>;
      return list.map((e) => ShikimoriAnime.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Get popular/ongoing anime for home page.
  Future<List<ShikimoriAnime>> getPopular({
    int limit = 50,
    String order = 'popularity',
    String? status,
    String? kind,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'order': order,
      };
      if (status != null) queryParams['status'] = status;
      if (kind != null) queryParams['kind'] = kind;

      final response = await _dio.get('/animes', queryParameters: queryParams);
      final list = response.data as List<dynamic>;
      return list.map((e) => ShikimoriAnime.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Get anime details by ID.
  Future<ShikimoriAnimeDetails> getDetails(int id) async {
    try {
      final response = await _dio.get('/animes/$id');
      return ShikimoriAnimeDetails.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Get anime by franchise (related releases).
  Future<List<ShikimoriAnime>> getByFranchise(String franchise, {int limit = 50}) async {
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
      return list.map((e) => ShikimoriAnime.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Episode stills for an anime (used as "кадры из серий").
  Future<List<String>> screenshots(int id) async {
    try {
      final response = await _dio.get('/animes/$id/screenshots');
      final list = response.data as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => ShikimoriConfig.imageUrl(item['original'] as String?))
          .whereType<String>()
          .toList();
    } on DioException catch (e) {
      // Screenshots are optional decoration: do not fail the details page.
      if (e.response?.statusCode == 404) return const [];
      throw ApiException.fromDio(e);
    }
  }
}