// Unified metadata model that all metadata providers map to.
// This is the single type used throughout the app for anime metadata.
class UnifiedMetadata {
  const UnifiedMetadata({
    required this.id,
    required this.shikimoriId,
    required this.title,
    this.englishTitle,
    this.japaneseTitle,
    this.synopsis,
    this.description,
    this.score,
    this.year,
    this.episodes,
    this.duration,
    this.status,
    this.kind,
    this.genres = const [],
    this.studios = const [],
    this.posterUrl,
    this.backgroundUrl,
    this.trailerUrl,
    this.trailerThumbnail,
    this.trailerSite,
    this.screenshots = const [],
    this.ageRating,
    this.franchise,
  });

  /// Provider's internal ID (e.g., AniList ID, Kitsu ID)
  final int id;

  /// Shikimori ID (canonical for cross-referencing)
  final int shikimoriId;

  /// Main title (prefer Russian)
  final String title;

  /// English title
  final String? englishTitle;

  /// Japanese title
  final String? japaneseTitle;

  /// Short synopsis
  final String? synopsis;

  /// Full description (HTML stripped)
  final String? description;

  /// Score normalized to 10-point scale
  final double? score;

  /// Release year
  final int? year;

  /// Total episode count
  final int? episodes;

  /// Episode duration in minutes
  final int? duration;

  /// Status string (e.g., "released", "ongoing")
  final String? status;

  /// Kind (tv, movie, ova, etc.)
  final String? kind;

  /// Genre list
  final List<String> genres;

  /// Studio list
  final List<String> studios;

  /// Poster image URL
  final String? posterUrl;

  /// Background/fanart URL
  final String? backgroundUrl;

  /// Trailer URL
  final String? trailerUrl;

  /// Trailer thumbnail URL
  final String? trailerThumbnail;

  /// Trailer site (youtube, dailymotion)
  final String? trailerSite;

  /// Episode screenshots
  final List<String> screenshots;

  /// Age rating
  final String? ageRating;

  /// Franchise identifier
  final String? franchise;

  /// Create empty metadata for missing entries
  factory UnifiedMetadata.empty({required int shikimoriId}) => UnifiedMetadata(
    id: 0,
    shikimoriId: shikimoriId,
    title: '',
  );

  /// Copy with modified fields
  UnifiedMetadata copyWith({
    int? id,
    int? shikimoriId,
    String? title,
    String? englishTitle,
    String? japaneseTitle,
    String? synopsis,
    String? description,
    double? score,
    int? year,
    int? episodes,
    int? duration,
    String? status,
    String? kind,
    List<String>? genres,
    List<String>? studios,
    String? posterUrl,
    String? backgroundUrl,
    String? trailerUrl,
    String? trailerThumbnail,
    String? trailerSite,
    List<String>? screenshots,
    String? ageRating,
    String? franchise,
  }) {
    return UnifiedMetadata(
      id: id ?? this.id,
      shikimoriId: shikimoriId ?? this.shikimoriId,
      title: title ?? this.title,
      englishTitle: englishTitle ?? this.englishTitle,
      japaneseTitle: japaneseTitle ?? this.japaneseTitle,
      synopsis: synopsis ?? this.synopsis,
      description: description ?? this.description,
      score: score ?? this.score,
      year: year ?? this.year,
      episodes: episodes ?? this.episodes,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      genres: genres ?? this.genres,
      studios: studios ?? this.studios,
      posterUrl: posterUrl ?? this.posterUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      trailerThumbnail: trailerThumbnail ?? this.trailerThumbnail,
      trailerSite: trailerSite ?? this.trailerSite,
      screenshots: screenshots ?? this.screenshots,
      ageRating: ageRating ?? this.ageRating,
      franchise: franchise ?? this.franchise,
    );
  }

  // ============ JSON serialization (persistent cache) ============

  Map<String, dynamic> toJson() => {
        'id': id,
        'shikimoriId': shikimoriId,
        'title': title,
        if (englishTitle != null) 'englishTitle': englishTitle,
        if (japaneseTitle != null) 'japaneseTitle': japaneseTitle,
        if (synopsis != null) 'synopsis': synopsis,
        if (description != null) 'description': description,
        if (score != null) 'score': score,
        if (year != null) 'year': year,
        if (episodes != null) 'episodes': episodes,
        if (duration != null) 'duration': duration,
        if (status != null) 'status': status,
        if (kind != null) 'kind': kind,
        'genres': genres,
        'studios': studios,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (backgroundUrl != null) 'backgroundUrl': backgroundUrl,
        if (trailerUrl != null) 'trailerUrl': trailerUrl,
        if (trailerThumbnail != null) 'trailerThumbnail': trailerThumbnail,
        if (trailerSite != null) 'trailerSite': trailerSite,
        'screenshots': screenshots,
        if (ageRating != null) 'ageRating': ageRating,
        if (franchise != null) 'franchise': franchise,
      };

  factory UnifiedMetadata.fromJson(Map<String, dynamic> json) {
    return UnifiedMetadata(
      id: json['id'] as int,
      shikimoriId: json['shikimoriId'] as int,
      title: json['title'] as String,
      englishTitle: json['englishTitle'] as String?,
      japaneseTitle: json['japaneseTitle'] as String?,
      synopsis: json['synopsis'] as String?,
      description: json['description'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      year: json['year'] as int?,
      episodes: json['episodes'] as int?,
      duration: json['duration'] as int?,
      status: json['status'] as String?,
      kind: json['kind'] as String?,
      genres: (json['genres'] as List? ?? const []).cast<String>(),
      studios: (json['studios'] as List? ?? const []).cast<String>(),
      posterUrl: json['posterUrl'] as String?,
      backgroundUrl: json['backgroundUrl'] as String?,
      trailerUrl: json['trailerUrl'] as String?,
      trailerThumbnail: json['trailerThumbnail'] as String?,
      trailerSite: json['trailerSite'] as String?,
      screenshots: (json['screenshots'] as List? ?? const []).cast<String>(),
      ageRating: json['ageRating'] as String?,
      franchise: json['franchise'] as String?,
    );
  }
}