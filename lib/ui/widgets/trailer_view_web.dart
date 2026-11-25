import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

final Map<String, String> _registeredViews = {};

/// Зарегистрированный на web iframe с трейлером.
///
/// [ambient] — фоновый режим: без звука, без контролов, зациклен.
/// Иначе — обычный плеер YouTube со звуком и управлением.
Widget buildTrailerView(String youtubeId, {bool ambient = true}) {
  final embedUrl = ambient
      ? 'https://www.youtube.com/embed/$youtubeId'
            '?autoplay=1&mute=1&loop=1&playlist=$youtubeId'
            '&controls=0&modestbranding=1&rel=0&playsinline=1'
            '&iv_load_policy=3&disablekb=1&fs=0'
      : 'https://www.youtube.com/embed/$youtubeId'
            '?autoplay=1&mute=0&rel=0&modestbranding=1&playsinline=1'
            '&iv_load_policy=3';

  final key = '$youtubeId|${ambient ? 'ambient' : 'interactive'}';
  final viewType = _registeredViews.putIfAbsent(key, () {
    final type = 'anishka-trailer-$key';
    ui_web.platformViewRegistry.registerViewFactory(type, (viewId) {
      final frame = web.HTMLIFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = ambient ? 'none' : 'auto'
        ..style.background = 'transparent'
        ..allowFullscreen = !ambient;
      frame.setAttribute(
        'allow',
        ambient
            ? 'autoplay; encrypted-media; picture-in-picture'
            : 'autoplay; encrypted-media; picture-in-picture; fullscreen',
      );
      frame.setAttribute('tabindex', ambient ? '-1' : '0');
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

      // youtube всегда держит 16:9; в фоновом режиме растягиваем
      // iframe так, чтобы видео закрывало весь баннер.
      if (!ambient) {
        return HtmlElementView(viewType: viewType);
      }

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
