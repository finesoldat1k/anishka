import 'package:material_ui/material_ui.dart';

import 'embed_frame_stub.dart'
    if (dart.library.html) 'embed_frame_web.dart'
    if (dart.library.io) 'embed_frame_native.dart'
    as impl;

/// A provider player rendered inside an `<iframe>` on web, or WebView on
/// supported native platforms (Android, iOS, macOS).
///
/// Studios from YummyAnime (Kodik, Alloha, Aksor, CVH, ...) only expose an
/// embed URL. When [isEmbedSupported] is true the player keeps playback
/// in-app; on desktop Linux/Windows the player resolves a direct stream
/// instead.
class EmbedFrame extends StatelessWidget {
  const EmbedFrame({super.key, required this.url, this.title = ''});

  final String url;
  final String title;

  /// Whether this platform can render provider embeds in-app.
  static bool get isEmbedSupported => impl.isEmbedSupported;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return impl.buildEmbedFrame(url, title: title);
  }
}
