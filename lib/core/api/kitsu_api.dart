// Kitsu REST client: extra posters, synopsis, ratings and YouTube trailers.
import 'dart:async';

import 'package:dio/dio.dart';

class KitsuMedia {
  const KitsuMedia({
    required this.id,
    this.canonicalTitle,
    this.englishTitle,
    this.japaneseTitle,
    this.synopsis,
    this.posterUrl,
    this.coverUrl,
    this.score,
    this.year,
    this.episodes,
    this.episodeLength,
    this.youtubeVideoId,
    this.ageRating,
    this.status,
  });

  final String id;
  final String? canonicalTitle;
  final String? englishTitle;
  final String? japaneseTitle;
  final String? synopsis;
  final String? posterUrl;
  final String? coverUrl;

  /// Score normalised to a 10-point scale.
  final double? score;
  final int? year;
  final int? episodes;

  /// Episode length in minutes.
  final int? episodeLength;
  final String? youtubeVideoId;
  final String? ageRating;
  final String? status;

  factory KitsuMedia.fromJson(Map<String, dynamic> json) {
    final attributes =
        (json['attributes'] as Map<String, dynamic>?) ?? const {};
    final titles = (attributes['titles'] as Map<String, dynamic>?) ?? const {};
    final poster =
        (attributes['posterImage'] as Map<String, dynamic>?) ?? const {};
    final cover =
        (attributes['coverImage'] as Map<String, dynamic>?) ?? const {};
    final rating = double.tryParse(
      attributes['averageRating']?.toString() ?? '',
    );
    final startDate = attributes['startDate']?.toString();

    return KitsuMedia(
      id: json['id']?.toString() ?? '',
      canonicalTitle: attributes['canonicalTitle'] as String?,
      englishTitle: (titles['en'] as String?) ?? (titles['en_us'] as String?),
      japaneseTitle: titles['ja_jp'] as String?,
      synopsis: attributes['synopsis'] as String?,
      posterUrl:
          (poster['large'] as String?) ?? (poster['original'] as String?),
      coverUrl: (cover['large'] as String?) ?? (cover['original'] as String?),
      score: rating == null ? null : rating / 10,
      year: startDate != null && startDate.length >= 4
          ? int.tryParse(startDate.substring(0, 4))
          : null,
      episodes: attributes['episodeCount'] as int?,
      episodeLength: attributes['episodeLength'] as int?,
      youtubeVideoId: attributes['youtubeVideoId'] as String?,
      ageRating: attributes['ageRating'] as String?,
      status: attributes['status'] as String?,
    );
  }
}

class KitsuApi {
  KitsuApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://kitsu.io/api/edge',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 18),
              headers: const {'Accept': 'application/vnd.api+json'},
            ),
          );

  final Dio _dio;
  final Map<String, KitsuMedia?> _cache = {};

  /// Find an anime by title. Never throws.
  Future<KitsuMedia?> find(String search) async {
    final query = search.trim();
    if (query.isEmpty) return null;
    final key = query.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/anime',
        queryParameters: {'filter[text]': query, 'page[limit]': 5},
      );
      final data = response.data?['data'];
      KitsuMedia? result;
      if (data is List && data.isNotEmpty) {
        result = KitsuMedia.fromJson(data.first as Map<String, dynamic>);
      }
      _cache[key] = result;
      return result;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }
}
