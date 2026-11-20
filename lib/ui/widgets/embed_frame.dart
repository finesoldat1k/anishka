import 'package:material_ui/material_ui.dart';

import 'embed_frame_stub.dart'
    if (dart.library.html) 'embed_frame_web.dart'
    as impl;

/// A provider player rendered inside an `<iframe>` on web.
///
/// Studios from YummyAnime (Kodik, Alloha, Aksor, CVH, ...) only expose an
/// embed URL. On native platforms iframe embedding is unavailable, so the
/// caller is expected to offer an external-open action instead.
class EmbedFrame extends StatelessWidget {
  const EmbedFrame({super.key, required this.url, this.title = ''});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    return impl.buildEmbedFrame(url, title: title);
  }
}
