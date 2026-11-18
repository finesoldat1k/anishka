import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/anime_franchise.dart';
import '../models/anime_release.dart';
import '../models/release_page.dart';
import 'api_config.dart';
import 'exceptions.dart';
import 'json_utils.dart';

class AniLibriaApi {
  AniLibriaApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.apiBase,
              connectTimeout: const Duration(seconds: 18),
              receiveTimeout: const Duration(seconds: 24),
              sendTimeout: const Duration(seconds: 12),
              headers: const {
                'Accept': 'application/json',
                'Accept-Language': 'ru',
              },
            ),
          );

  final Dio _dio;

  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<Object?>(path, queryParameters: query);
      final data = response.data;
      if (data is String) {
        final text = data.trimLeft();
        if (text.startsWith('{') || text.startsWith('[')) {
          return jsonDecode(text);
        }
        throw const ApiException('сервер вернул неожиданный ответ.');
      }
      return data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException('не удалось разобрать ответ сервера.');
    }
  }

  Future<ReleasePage> ongoing({int page = 1, int limit = 24}) async {
    final data = asMap(
      await _get(
        '/anime/catalog/releases',
        query: {
          'page': page,
          'limit': limit,
          'f[publish_statuses]': 'IS_ONGOING',
          'f[sorting]': 'FRESH_AT_DESC',
        },
      ),
    );
    final items = asMapList(data['data'])
        .map(AnimeRelease.fromJson)
        .where((release) => release.id > 0)
        .toList();
    final pagination = asMap(asMap(data['meta'])['pagination']);
    return ReleasePage(
      items: items,
      page: asInt(pagination['current_page']) ?? page,
      totalPages: asInt(pagination['total_pages']) ?? page,
      total: asInt(pagination['total']) ?? items.length,
    );
  }

  Future<List<AnimeRelease>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final data = await _get('/app/search/releases', query: {'query': value});
    return asMapList(data)
        .map(AnimeRelease.fromJson)
        .where((release) => release.id > 0)
        .toList();
  }

  /// Find releases by Shikimori anime ID.
  /// Searches by name and filters exact matches by shikimori.id.
  Future<List<AnimeRelease>> findByShikimoriId(int shikimoriId, {String? nameHint}) async {
    final results = <AnimeRelease>[];
    final searched = <String>{};

    // Strategy 1: If we have a name hint, search by it.
    if (nameHint != null && nameHint.isNotEmpty) {
      final hint = nameHint.trim();
      if (searched.add(hint)) {
        final data = await _get('/anime/catalog/releases', query: {'f[search]': hint, 'limit': 50});
        final items = asMapList(asMap(data)['data'])
            .map(AnimeRelease.fromJson)
            .where((r) => r.id > 0 && r.shikimoriId == shikimoriId)
            .toList();
        results.addAll(items);
      }
    }

    // Strategy 2: Search by common name variations (russian/english from Shikimori).
    // This is a fallback - the caller should provide the best name hint.

    return results;
  }

  Future<AnimeRelease> release(int id) async {
    final data = await _get('/anime/releases/$id');
    final map = asMap(data);
    if (map.isEmpty) {
      throw const ApiException('релиз не найден.', statusCode: 404);
    }
    return AnimeRelease.fromJson(map);
  }

  Future<List<AnimeFranchise>> franchises(int releaseId) async {
    try {
      final data = await _get('/anime/franchises/release/$releaseId');
      return asMapList(data)
          .map(AnimeFranchise.fromJson)
          .where((franchise) => franchise.releases.isNotEmpty)
          .toList();
    } on ApiException catch (error) {
      if (error.statusCode == 404) return const [];
      rethrow;
    }
  }
}
