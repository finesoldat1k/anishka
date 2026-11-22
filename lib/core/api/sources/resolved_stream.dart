// A resolved, directly playable stream with the headers it requires.
//
// Provider players (Kodik, Aniboom, CDNVideoHub, ...) hand out signed URLs
// that reject requests without a matching `Referer`/`Origin`. Carrying those
// headers next to the URL lets the player feed them to media_kit instead of
// silently failing with a 403.

/// Container/transport kind of a resolved stream.
enum StreamKind {
  /// Unknown or auto-detected by the player.
  auto,

  /// HTTP Live Streaming playlist.
  hls,

  /// MPEG-DASH manifest.
  dash,

  /// Progressive MP4 file.
  mp4;

  static StreamKind fromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m3u8')) return StreamKind.hls;
    if (path.endsWith('.mpd')) return StreamKind.dash;
    if (path.endsWith('.mp4')) return StreamKind.mp4;
    return StreamKind.auto;
  }

  String get wireName => name;

  static StreamKind fromWire(String? value) {
    return switch (value) {
      'hls' => StreamKind.hls,
      'dash' => StreamKind.dash,
      'mp4' => StreamKind.mp4,
      _ => StreamKind.auto,
    };
  }
}

/// A direct stream URL plus everything needed to play it.
class ResolvedStream {
  const ResolvedStream({
    required this.url,
    this.headers = const {},
    this.kind = StreamKind.auto,
    this.quality,
  });

  /// Absolute, directly playable URL.
  final String url;

  /// HTTP headers the CDN expects (referer, origin, user-agent, ...).
  final Map<String, String> headers;

  /// Stream container.
  final StreamKind kind;

  /// Quality label this URL represents (e.g. `720`), when known.
  final String? quality;

  bool get isPlayable => url.trim().isNotEmpty;

  ResolvedStream copyWith({
    String? url,
    Map<String, String>? headers,
    StreamKind? kind,
    String? quality,
  }) {
    return ResolvedStream(
      url: url ?? this.url,
      headers: headers ?? this.headers,
      kind: kind ?? this.kind,
      quality: quality ?? this.quality,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (headers.isNotEmpty) 'headers': headers,
        'kind': kind.wireName,
        if (quality != null) 'quality': quality,
      };

  factory ResolvedStream.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    return ResolvedStream(
      url: json['url'] as String? ?? '',
      headers: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      kind: StreamKind.fromWire(json['kind'] as String?),
      quality: json['quality']?.toString(),
    );
  }

  @override
  String toString() =>
      'ResolvedStream(${kind.name}, quality: $quality, headers: ${headers.keys.join(', ')})';
}
