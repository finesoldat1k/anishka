import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/anime_franchise.dart';
import '../../models/anime_release.dart';
import '../../models/release_page.dart';
import '../api_config.dart';
import '../exceptions.dart';
import '../json_utils.dart';
import 'source_provider.dart';
import 'unified_source.dart';

class AniLibria implements SourceProvider {
  AniLibria({Dio? dio})
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

  @override
  String get displayName => 'anilibria';

  @override
  String get id => 'anilibria';

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

  @override
  Future<List<UnifiedSource>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final data = await _get('/app/search/releases', query: {'query': value});
    return asMapList(data)
        .map(AnimeRelease.fromJson)
        .where((release) => release.id > 0)
        .map(_toUnified)
        .toList();
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    final results = <UnifiedSource>[];
    final searched = <String>{};

    if (nameHint != null && nameHint.isNotEmpty) {
      final hint = nameHint.trim();
      if (searched.add(hint)) {
        final data = await _get(
          '/anime/catalog/releases',
          query: {'f[search]': hint, 'limit': 50},
        );
        final items = asMapList(asMap(data)['data'])
            .map(AnimeRelease.fromJson)
            .where((r) => r.id > 0 && r.shikimoriId == shikimoriId)
            .map(_toUnified)
            .toList();
        results.addAll(items);
      }
    }

    return results;
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final id = int.tryParse(sourceId);
    if (id == null) return null;
    try {
      final data = await _get('/anime/releases/$id');
      final map = asMap(data);
      if (map.isEmpty) return null;
      return _toUnified(AnimeRelease.fromJson(map));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<dynamic>> getFranchises(int releaseId) async {
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

  /// Get ongoing releases for home page (AniLibria-specific).
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

  UnifiedSource _toUnified(AnimeRelease release) {
    final episodes = release.episodes
        .map(
          (e) => UnifiedEpisode(
            id: 'anilibria:${release.id}:${e.id}',
            ordinal: e.ordinal,
            title: e.name ?? 'серия ${e.ordinal}',
            duration: e.duration?.inSeconds,
            posterUrl: e.previewUrl,
            hls480: e.hls480,
            hls720: e.hls720,
            hls1080: e.hls1080,
            openingStart: e.openingStart,
            openingStop: e.openingStop,
            endingStart: e.endingStart,
            endingStop: e.endingStop,
          ),
        )
        .toList();

    final members = release.voiceActors.isNotEmpty
        ? release.voiceActors
        : release.members;

    return UnifiedSource(
      id: 'anilibria:${release.id}',
      providerId: 'anilibria',
      title: 'AniLibria',
      subtitle: members.isNotEmpty
          ? 'озвучка студии · ${members.map((m) => m.nickname).join(', ')}'
          : 'озвучка студии',
      logoUrl: 'https://anilibria.top/favicon.ico',
      episodeCount: episodes.length,
      episodes: episodes,
      hasDirectStreams: episodes.any((e) => e.hasDirectStream),
      requiresResolution: false,
    );
  }
}