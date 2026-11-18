import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';

final Map<String, String> _registeredViews = {};

/// Зарегистрированный на web iframe с зацикленным трейлером без звука.
Widget buildTrailerView(String youtubeId) {
  final embedUrl =
      'https://www.youtube.com/embed/$youtubeId'
      '?autoplay=1&mute=1&loop=1&playlist=$youtubeId'
      '&controls=0&modestbranding=1&rel=0&playsinline=1'
      '&iv_load_policy=3&disablekb=1&fs=0';

  final viewType = _registeredViews.putIfAbsent(youtubeId, () {
    final type = 'anishka-trailer-$youtubeId';
    ui_web.platformViewRegistry.registerViewFactory(type, (viewId) {
      final frame = html.IFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none'
        ..style.background = 'transparent'
        ..allowFullscreen = false;
      frame.setAttribute(
        'allow',
        'autoplay; encrypted-media; picture-in-picture',
      );
      frame.setAttribute('tabindex', '-1');
      frame.setAttribute('title', 'трейлер');
      return frame;
    });
    return type;
  });

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      if (width <= 0 || height <= 0) return const SizedBox.shrink();

      // youtube всегда держит 16:9. растягиваем iframe так, чтобы видео
      // закрывало весь баннер, а лишнее обрезалось по краям.
      final videoHeight = width * 9 / 16;
      final videoWidth = height * 16 / 9;
      final fitsByHeight = videoHeight >= height;
      final targetWidth = fitsByHeight ? width : videoWidth;
      final targetHeight = fitsByHeight ? videoHeight : height;

      return ClipRect(
        child: OverflowBox(
          minWidth: targetWidth,
          maxWidth: targetWidth,
          minHeight: targetHeight,
          maxHeight: targetHeight,
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: HtmlElementView(viewType: viewType),
          ),
        ),
      );
    },
  );
}
