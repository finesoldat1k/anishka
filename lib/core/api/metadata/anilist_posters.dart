// AniList poster fallback for entries with a missing Shikimori image.
//
// Shikimori returns `/assets/globals/missing_original.jpg` for many freshly
// added ongoing anime. The app hides those placeholders, which used to leave
// cards without any artwork. AniList is keyed by MyAnimeList IDs, and
// Shikimori uses MAL IDs, so a single batched GraphQL request can fill the
// gaps without title matching.

import 'package:dio/dio.dart';

class AniListPosterService {
  AniListPosterService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://graphql.anilist.co',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          );

  final Dio _dio;

  /// Positive and negative results both live for the app session, so a list
  /// scroll never re-queries the same missing poster.
  final Map<int, String?> _posters = {};

  /// Look up posters for a set of Shikimori/MAL IDs.
  ///
  /// Failures are deliberately swallowed: artwork is optional and a broken
  /// fallback must never delay or break the catalog.
  Future<Map<int, String>> postersForIds(Iterable<int> ids) async {
    final wanted = ids.where((id) => id > 0).toSet().toList();
    final result = <int, String>{};
    final missing = <int>[];

    for (final id in wanted) {
      if (_posters.containsKey(id)) {
        final cached = _posters[id];
        if (cached != null && cached.isNotEmpty) result[id] = cached;
      } else {
        missing.add(id);
      }
    }

    for (var start = 0; start < missing.length; start += 50) {
      final end = (start + 50).clamp(0, missing.length);
      final chunk = missing.sublist(start, end);
      final found = await _fetchChunk(chunk);
      for (final id in chunk) {
        final poster = found[id];
        _posters[id] = poster;
        if (poster != null && poster.isNotEmpty) result[id] = poster;
      }
    }

    return result;
  }

  Future<String?> posterFor(int id) async {
    final posters = await postersForIds([id]);
    return posters[id];
  }

  Future<Map<int, String>> _fetchChunk(List<int> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '',
        data: {
          'query':
              '''
query {
  Page(perPage: ${ids.length}) {
    media(idMal_in: [${ids.join(', ')}], type: ANIME) {
      idMal
      coverImage { extraLarge large }
    }
  }
}
''',
        },
      );
      final data = response.data;
      if (data == null) return const {};
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) return const {};
      final page = (data['data'] as Map?)?['Page'];
      final media = (page as Map?)?['media'];
      if (media is! List) return const {};

      final result = <int, String>{};
      for (final item in media) {
        if (item is! Map) continue;
        final id = item['idMal'];
        if (id is! int) continue;
        final cover = item['coverImage'];
        if (cover is! Map) continue;
        final poster = cover['extraLarge'] ?? cover['large'];
        if (poster is! String || poster.isEmpty) continue;
        result.putIfAbsent(id, () => poster);
      }
      return result;
    } catch (_) {
      return const {};
    }
  }
}
