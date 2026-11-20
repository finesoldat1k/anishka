import 'package:material_ui/material_ui.dart';

/// Native platforms cannot embed an arbitrary provider page.
///
/// The player screen handles this case by offering an external-open action,
/// so this widget is only a safety net.
Widget buildEmbedFrame(String url, {String title = ''}) {
  return const SizedBox.shrink();
}
