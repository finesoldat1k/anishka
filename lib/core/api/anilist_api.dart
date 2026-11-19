// AniList GraphQL client: trailers, banners, scores and English descriptions.
import 'dart:async';

import 'package:dio/dio.dart';

/// Compact representation of an AniList media entry.
class AniListMedia {
  const AniListMedia({
    required this.id,
    this.romaji,
    this.english,
    this.native,
    this.description,
    this.score,
    this.year,
    this.episodes,
    this.duration,
    this.status,
    this.format,
    this.genres = const [],
    this.studios = const [],
    this.posterUrl,
    this.bannerUrl,
    this.trailerUrl,
    this.trailerThumbnail,
    this.trailerSite,
  });

  final int id;
  final String? romaji;
  final String? english;
  final String? native;
  final String? description;

  /// Score normalised to a 10-point scale.
  final double? score;
  final int? year;
  final int? episodes;

  /// Episode duration in minutes.
  final int? duration;
  final String? status;
  final String? format;
  final List<String> genres;
  final List<String> studios;
  final String? posterUrl;
  final String? bannerUrl;
  final String? trailerUrl;
  final String? trailerThumbnail;
  final String? trailerSite;

  String? get displayEnglish => english?.trim().isNotEmpty == true ? english : null;

  factory AniListMedia.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as Map<String, dynamic>?) ?? const {};
    final cover = (json['coverImage'] as Map<String, dynamic>?) ?? const {};
    final trailer = (json['trailer'] as Map<String, dynamic>?) ?? const {};
    final studioNodes =
        ((json['studios'] as Map<String, dynamic>?) ?? const {})['nodes'];
    final scoreValue = json['averageScore'];
    final trailerSite = (trailer['site'] as String?)?.toLowerCase();
    final trailerId = trailer['id'] as String?;
    String? trailerUrl;
    String? trailerThumbnail = trailer['thumbnail'] as String?;
    if (trailerId != null && trailerId.isNotEmpty) {
      if (trailerSite == 'youtube') {
        trailerUrl = 'https://www.youtube.com/watch?v=$trailerId';
        trailerThumbnail ??= 'https://img.youtube.com/vi/$trailerId/hqdefault.jpg';
      } else if (trailerSite == 'dailymotion') {
        trailerUrl = 'https://www.dailymotion.com/video/$trailerId';
      }
    }

    return AniListMedia(
      id: json['id'] as int? ?? 0,
      romaji: title['romaji'] as String?,
      english: title['english'] as String?,
      native: title['native'] as String?,
      description: _cleanDescription(json['description'] as String?),
      score: scoreValue is num ? scoreValue / 10 : null,
      year: json['seasonYear'] as int?,
      episodes: json['episodes'] as int?,
      duration: json['duration'] as int?,
      status: json['status'] as String?,
      format: json['format'] as String?,
      genres: (json['genres'] as List?)?.cast<String>() ?? const [],
      studios: studioNodes is List
          ? studioNodes
              .whereType<Map<String, dynamic>>()
              .map((node) => (node['name'] as String? ?? '').trim())
              .where((name) => name.isNotEmpty)
              .toList()
          : const [],
      posterUrl: (cover['extraLarge'] as String?) ?? (cover['large'] as String?),
      bannerUrl: json['bannerImage'] as String?,
      trailerUrl: trailerUrl,
      trailerThumbnail: trailerThumbnail,
      trailerSite: trailerSite,
    );
  }

  static String? _cleanDescription(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final cleaned = text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return cleaned.toLowerCase();
  }
}

class AniListApi {
  AniListApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://graphql.anilist.co',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 18),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  static const _query = r'''
    query ($search: String) {
      Media(search: $search, type: ANIME, sort: SEARCH_MATCH) {
        id
        title { romaji english native }
        description(asHtml: false)
        averageScore
        seasonYear
        episodes
        duration
        status
        format
        genres
        coverImage { extraLarge large }
        bannerImage
        trailer { id site thumbnail }
        studios(isMain: true) { nodes { name } }
      }
    }
  ''';

  final Dio _dio;
  final Map<String, AniListMedia?> _cache = {};

  /// Find the best matching anime by title. Never throws: metadata enrichment
  /// is optional and must not break the details page.
  Future<AniListMedia?> find(String search) async {
    final query = search.trim();
    if (query.isEmpty) return null;
    final key = query.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/',
        data: {
          'query': _query,
          'variables': {'search': query},
        },
      );
      final data = response.data?['data'];
      final media = data is Map<String, dynamic> ? data['Media'] : null;
      final result = media is Map<String, dynamic>
          ? AniListMedia.fromJson(media)
          : null;
      _cache[key] = result;
      return result;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }
}
