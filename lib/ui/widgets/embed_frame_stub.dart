import 'package:material_ui/material_ui.dart';

/// Platforms without an in-app WebView cannot render provider embeds.
///
/// The player screen checks [isEmbedSupported] and resolves a direct stream
/// instead, so this widget is only a safety net.
bool get isEmbedSupported => false;

Widget buildEmbedFrame(String url, {String title = ''}) {
  return const SizedBox.shrink();
}
