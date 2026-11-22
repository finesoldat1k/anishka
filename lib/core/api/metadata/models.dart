// Shared models for metadata providers.

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

  String? get displayEnglish =>
      english?.trim().isNotEmpty == true ? english : null;

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
        trailerThumbnail ??=
            'https://img.youtube.com/vi/$trailerId/hqdefault.jpg';
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
      posterUrl:
          (cover['extraLarge'] as String?) ?? (cover['large'] as String?),
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
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return cleaned.toLowerCase();
  }
}

/// Kitsu REST client: extra posters, synopsis, ratings and YouTube trailers.
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
    return _fromJson(json, const {});
  }

  factory KitsuMedia.fromJsonWithIncluded(
    Map<String, dynamic> json,
    Map<String, Map<String, dynamic>> included,
  ) {
    return _fromJson(json, included);
  }

  static KitsuMedia _fromJson(
    Map<String, dynamic> json,
    Map<String, Map<String, dynamic>> included,
  ) {
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
