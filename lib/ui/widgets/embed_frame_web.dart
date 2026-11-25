import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

final Map<String, String> _registeredViews = {};

/// Browsers render provider embeds in a sandboxed iframe.
bool get isEmbedSupported => true;

/// Registers a platform view once per embed URL and returns its iframe.
Widget buildEmbedFrame(String url, {String title = ''}) {
  final viewType = _registeredViews.putIfAbsent(url, () {
    final type = 'anishka-embed-${url.hashCode}-${_registeredViews.length}';
    ui_web.platformViewRegistry.registerViewFactory(type, (viewId) {
      final frame = web.HTMLIFrameElement()
        ..src = url
        ..title = title
        ..allowFullscreen = true
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000'
        ..setAttribute(
          'allow',
          'autoplay; fullscreen; encrypted-media; picture-in-picture',
        )
        ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
      return frame;
    });
    return type;
  });

  return HtmlElementView(viewType: viewType);
}
