// Unified video source interface for multi-source playback.

/// Represents a video source (AniLibria, AnimeVost, AniDub, Kodik, Moonwalk, etc.)
abstract class VideoSource {
  /// Unique identifier: 'anilibria', 'animevost', 'anidub', 'kodik', 'moonwalk'
  String get sourceId;

  /// Human-readable name: 'AniLibria', 'AnimeVost', 'AniDub', 'Kodik', 'Moonwalk'
  String get displayName;

  /// Search for anime by title, returns list of source-specific anime entries
  Future<List<SourceAnimeEntry>> search(String query, {int limit = 50});

  /// Get anime details by source-specific ID
  Future<SourceAnimeDetails?> getDetails(String sourceId);

  /// Get episodes for a specific anime (source-specific ID)
  Future<List<SourceEpisode>> getEpisodes(String sourceAnimeId);

  /// Get HLS/MP4 stream URL for episode at quality
  Future<String?> getStreamUrl(String sourceEpisodeId, String quality);

  /// Available qualities for this source
  List<String> get availableQualities;

  /// Check if source is available/healthy
  Future<bool> healthCheck();

  /// Priority for fallback (lower = higher priority)
  int get priority;
}

/// Generic anime entry from any source (for search results)
class SourceAnimeEntry {
  const SourceAnimeEntry({
    required this.sourceId,
    required this.externalId,
    required this.title,
    this.russianTitle,
    this.posterUrl,
    this.year,
    this.kind,
    this.status,
    this.episodes,
    this.score,
  });

  final String sourceId;      // 'anilibria', 'animevost', etc.
  final String externalId;    // Source-specific ID
  final String title;         // Original/English title
  final String? russianTitle; // Russian title
  final String? posterUrl;
  final int? year;
  final String? kind;         // tv, movie, ova, etc.
  final String? status;       // ongoing, released, etc.
  final int? episodes;
  final String? score;

  String get displayTitle => russianTitle?.isNotEmpty == true ? russianTitle! : title;
}

/// Detailed anime from a specific source
class SourceAnimeDetails {
  const SourceAnimeDetails({
    required this.sourceId,
    required this.externalId,
    required this.title,
    this.russianTitle,
    this.description,
    this.posterUrl,
    this.backgroundUrl,
    this.year,
    this.kind,
    this.status,
    this.episodes,
    this.score,
    this.genres,
    this.studios,
    this.episodesList = const [],
  });

  final String sourceId;
  final String externalId;
  final String title;
  final String? russianTitle;
  final String? description;
  final String? posterUrl;
  final String? backgroundUrl;
  final int? year;
  final String? kind;
  final String? status;
  final int? episodes;
  final String? score;
  final List<String>? genres;
  final List<String>? studios;
  final List<SourceEpisode> episodesList;

  String get displayTitle => russianTitle?.isNotEmpty == true ? russianTitle! : title;
}

/// Episode from a specific source
class SourceEpisode {
  const SourceEpisode({
    required this.externalId,
    required this.ordinal,
    this.title,
    this.duration,
    this.posterUrl,
    this.hlsUrls = const {},      // quality -> HLS URL
    this.mp4Urls = const {},      // quality -> MP4 URL
  });

  final String externalId;
  final int ordinal;
  final String? title;
  final int? duration; // seconds
  final String? posterUrl;
  final Map<String, String> hlsUrls;     // '1080' -> url
  final Map<String, String> mp4Urls;     // '1080' -> url

  String? getStreamUrl(String quality) => hlsUrls[quality] ?? mp4Urls[quality];
  List<String> get availableQualities => [
    ...hlsUrls.keys,
    ...mp4Urls.keys.where((k) => !hlsUrls.containsKey(k)),
  ];
}