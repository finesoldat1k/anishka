import '../api/api_config.dart';
import '../api/json_utils.dart';
import '../utils/format.dart';

class AnimeEpisode {
  const AnimeEpisode({
    required this.id,
    required this.ordinal,
    required this.name,
    required this.hls480,
    required this.hls720,
    required this.hls1080,
    required this.durationSeconds,
    required this.previewPath,
    required this.openingStart,
    required this.openingStop,
    required this.endingStart,
    required this.endingStop,
    required this.sortOrder,
    this.resolverSource,
    this.resolverId,
    this.embedUrl,
    this.embedLabel,
  });

  final String id;
  final int ordinal;
  final String? name;
  final String? hls480;
  final String? hls720;
  final String? hls1080;
  final int? durationSeconds;
  final String? previewPath;
  final int? openingStart;
  final int? openingStop;
  final int? endingStart;
  final int? endingStop;
  final int? sortOrder;

  /// Lazy stream resolution for scraped sources (AnimeVost, AniDub, ...).
  final String? resolverSource;
  final String? resolverId;

  /// Embedded provider player (YummyAnime studios, Kodik, Alloha, ...).
  ///
  /// On web this URL is rendered in an iframe, which is the only playback path
  /// for providers that do not send CORS headers. On native platforms the
  /// direct [resolverSource] path is preferred and the embed is opened
  /// externally as a fallback.
  final String? embedUrl;
  final String? embedLabel;

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    final opening = asMap(json['opening']);
    final ending = asMap(json['ending']);
    return AnimeEpisode(
      id: asString(json['id']) ?? '',
      ordinal: asInt(json['ordinal']) ?? 1,
      name: asString(json['name']),
      hls480: asString(json['hls_480']),
      hls720: asString(json['hls_720']),
      hls1080: asString(json['hls_1080']),
      durationSeconds: asInt(json['duration']),
      previewPath:
          asString(asMap(json['preview'])['preview']) ??
          asString(asMap(json['preview'])['src']),
      openingStart: asInt(opening['start']),
      openingStop: asInt(opening['stop']),
      endingStart: asInt(ending['start']),
      endingStop: asInt(ending['stop']),
      sortOrder: asInt(json['sort_order']),
      resolverSource: asString(json['resolver_source']),
      resolverId: asString(json['resolver_id']),
      embedUrl: asString(json['embed_url']),
      embedLabel: asString(json['embed_label']),
    );
  }

  String? get previewUrl => ApiConfig.mediaUrl(previewPath);

  String? get streamUrl => hls1080 ?? hls720 ?? hls480;

  bool get canResolve =>
      resolverSource != null &&
      resolverSource!.isNotEmpty &&
      resolverId != null &&
      resolverId!.isNotEmpty;

  bool get hasStream =>
      streamUrl != null || canResolve || (embedUrl?.isNotEmpty ?? false);

  AnimeEpisode copyWith({
    String? hls480,
    String? hls720,
    String? hls1080,
  }) {
    return AnimeEpisode(
      id: id,
      ordinal: ordinal,
      name: name,
      hls480: hls480 ?? this.hls480,
      hls720: hls720 ?? this.hls720,
      hls1080: hls1080 ?? this.hls1080,
      durationSeconds: durationSeconds,
      previewPath: previewPath,
      openingStart: openingStart,
      openingStop: openingStop,
      endingStart: endingStart,
      endingStop: endingStop,
      sortOrder: sortOrder,
      resolverSource: resolverSource,
      resolverId: resolverId,
      embedUrl: embedUrl,
      embedLabel: embedLabel,
    );
  }

  String get displayName =>
      name == null || name!.trim().isEmpty ? 'серия $ordinal' : lc(name);

  Duration? get duration =>
      durationSeconds == null ? null : Duration(seconds: durationSeconds!);

  Duration? get openingStartDuration =>
      openingStart == null ? null : Duration(seconds: openingStart!);

  Duration? get openingStopDuration =>
      openingStop == null ? null : Duration(seconds: openingStop!);

  Duration? get endingStartDuration =>
      endingStart == null ? null : Duration(seconds: endingStart!);

  Duration? get endingStopDuration =>
      endingStop == null ? null : Duration(seconds: endingStop!);

  String? hlsForQuality(String quality) => switch (quality) {
    '1080' => hls1080,
    '720' => hls720,
    '480' => hls480,
    _ => streamUrl,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'ordinal': ordinal,
    'name': name,
    'hls_480': hls480,
    'hls_720': hls720,
    'hls_1080': hls1080,
    'duration': durationSeconds,
    'preview': {'preview': previewPath},
    'opening': {'start': openingStart, 'stop': openingStop},
    'ending': {'start': endingStart, 'stop': endingStop},
    'sort_order': sortOrder,
    'resolver_source': resolverSource,
    'resolver_id': resolverId,
    'embed_url': embedUrl,
    'embed_label': embedLabel,
  };
}
