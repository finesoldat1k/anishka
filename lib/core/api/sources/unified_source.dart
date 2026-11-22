// Unified source model that all video source providers map to.
// This is the single type used throughout the app for video sources.
class UnifiedSource {
  const UnifiedSource({
    required this.id,
    required this.providerId,
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.episodeCount = 0,
    this.episodes = const [],
    this.hasDirectStreams = false,
    this.requiresResolution = false,
  });

  /// Unique source identifier
  final String id;

  /// Provider ID (anilibria, animevost, anidub, yani, kodik)
  final String providerId;

  /// Display title (e.g., "AniLibria", "JAM CLUB")
  final String title;

  /// Subtitle (e.g., "озвучка студии · anilibria")
  final String? subtitle;

  /// Logo URL
  final String? logoUrl;

  /// Total episode count
  final int episodeCount;

  /// Episode list
  final List<UnifiedEpisode> episodes;

  /// Whether this source has direct HLS/MP4 streams
  final bool hasDirectStreams;

  /// Whether stream resolution is required
  final bool requiresResolution;

  /// Copy with modified fields
  UnifiedSource copyWith({
    String? id,
    String? providerId,
    String? title,
    String? subtitle,
    String? logoUrl,
    int? episodeCount,
    List<UnifiedEpisode>? episodes,
    bool? hasDirectStreams,
    bool? requiresResolution,
  }) {
    return UnifiedSource(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      logoUrl: logoUrl ?? this.logoUrl,
      episodeCount: episodeCount ?? this.episodeCount,
      episodes: episodes ?? this.episodes,
      hasDirectStreams: hasDirectStreams ?? this.hasDirectStreams,
      requiresResolution: requiresResolution ?? this.requiresResolution,
    );
  }

  // ============ JSON serialization (persistent cache) ============

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'episodeCount': episodeCount,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'hasDirectStreams': hasDirectStreams,
        'requiresResolution': requiresResolution,
      };

  factory UnifiedSource.fromJson(Map<String, dynamic> json) {
    return UnifiedSource(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      logoUrl: json['logoUrl'] as String?,
      episodeCount: json['episodeCount'] as int,
      episodes: (json['episodes'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(UnifiedEpisode.fromJson)
          .toList(),
      hasDirectStreams: json['hasDirectStreams'] as bool? ?? false,
      requiresResolution: json['requiresResolution'] as bool? ?? false,
    );
  }
}

class UnifiedEpisode {
  const UnifiedEpisode({
    required this.id,
    required this.ordinal,
    required this.title,
    this.duration,
    this.posterUrl,
    this.hls480,
    this.hls720,
    this.hls1080,
    this.openingStart,
    this.openingStop,
    this.endingStart,
    this.endingStop,
    this.embedUrl,
    this.embedLabel,
    this.resolverSource,
    this.resolverId,
  });

  /// Unique episode identifier
  final String id;

  /// Episode number
  final int ordinal;

  /// Episode title
  final String title;

  /// Duration in seconds
  final int? duration;

  /// Preview/poster URL
  final String? posterUrl;

  /// HLS/MP4 URLs by quality
  final String? hls480;
  final String? hls720;
  final String? hls1080;

  /// Skip timestamps
  final int? openingStart;
  final int? openingStop;
  final int? endingStart;
  final int? endingStop;

  /// Embed player fallback
  final String? embedUrl;
  final String? embedLabel;

  /// For resolved streams (aksor, kodik, etc.)
  final String? resolverSource;
  final String? resolverId;

  /// Get best available stream URL for quality
  String? hlsForQuality(String quality) {
    switch (quality) {
      case '1080':
        return hls1080 ?? hls720 ?? hls480;
      case '720':
        return hls720 ?? hls1080 ?? hls480;
      case '480':
        return hls480 ?? hls720 ?? hls1080;
      default:
        return hls1080 ?? hls720 ?? hls480;
    }
  }

  /// Whether this episode has a direct stream
  bool get hasDirectStream => hls480 != null || hls720 != null || hls1080 != null;

  /// Whether this episode can be resolved
  bool get canResolve => resolverSource != null && resolverId != null;

  /// Copy with modified fields
  UnifiedEpisode copyWith({
    String? id,
    int? ordinal,
    String? title,
    int? duration,
    String? posterUrl,
    String? hls480,
    String? hls720,
    String? hls1080,
    int? openingStart,
    int? openingStop,
    int? endingStart,
    int? endingStop,
    String? embedUrl,
    String? embedLabel,
    String? resolverSource,
    String? resolverId,
  }) {
    return UnifiedEpisode(
      id: id ?? this.id,
      ordinal: ordinal ?? this.ordinal,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      posterUrl: posterUrl ?? this.posterUrl,
      hls480: hls480 ?? this.hls480,
      hls720: hls720 ?? this.hls720,
      hls1080: hls1080 ?? this.hls1080,
      openingStart: openingStart ?? this.openingStart,
      openingStop: openingStop ?? this.openingStop,
      endingStart: endingStart ?? this.endingStart,
      endingStop: endingStop ?? this.endingStop,
      embedUrl: embedUrl ?? this.embedUrl,
      embedLabel: embedLabel ?? this.embedLabel,
      resolverSource: resolverSource ?? this.resolverSource,
      resolverId: resolverId ?? this.resolverId,
    );
  }

  // ============ JSON serialization (persistent cache) ============

  Map<String, dynamic> toJson() => {
        'id': id,
        'ordinal': ordinal,
        'title': title,
        if (duration != null) 'duration': duration,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (hls480 != null) 'hls480': hls480,
        if (hls720 != null) 'hls720': hls720,
        if (hls1080 != null) 'hls1080': hls1080,
        if (openingStart != null) 'openingStart': openingStart,
        if (openingStop != null) 'openingStop': openingStop,
        if (endingStart != null) 'endingStart': endingStart,
        if (endingStop != null) 'endingStop': endingStop,
        if (embedUrl != null) 'embedUrl': embedUrl,
        if (embedLabel != null) 'embedLabel': embedLabel,
        if (resolverSource != null) 'resolverSource': resolverSource,
        if (resolverId != null) 'resolverId': resolverId,
      };

  factory UnifiedEpisode.fromJson(Map<String, dynamic> json) {
    return UnifiedEpisode(
      id: json['id'] as String,
      ordinal: json['ordinal'] as int,
      title: json['title'] as String,
      duration: json['duration'] as int?,
      posterUrl: json['posterUrl'] as String?,
      hls480: json['hls480'] as String?,
      hls720: json['hls720'] as String?,
      hls1080: json['hls1080'] as String?,
      openingStart: json['openingStart'] as int?,
      openingStop: json['openingStop'] as int?,
      endingStart: json['endingStart'] as int?,
      endingStop: json['endingStop'] as int?,
      embedUrl: json['embedUrl'] as String?,
      embedLabel: json['embedLabel'] as String?,
      resolverSource: json['resolverSource'] as String?,
      resolverId: json['resolverId'] as String?,
    );
  }
}