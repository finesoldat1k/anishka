import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Видеоповерхность плеера.
///
/// На нативных платформах используется стандартный [Video] из media_kit.
/// В web он ждёт `width/height` от <video>, чтобы вставить html-элемент
/// в документ, но браузер не загружает метаданные у элемента вне dom.
/// Поэтому на web элемент монтируется сразу, с запасным соотношением 16:9,
/// а после загрузки метаданных подстраивается под реальный размер кадра.
class VideoSurface extends StatelessWidget {
  const VideoSurface({super.key, required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Video(
        controller: controller,
        controls: NoVideoControls,
        fit: BoxFit.contain,
        fill: Colors.black,
        wakelock: true,
        pauseUponEnteringBackgroundMode: true,
      );
    }

    return ValueListenableBuilder<int?>(
      valueListenable: controller.id,
      builder: (context, id, _) {
        if (id == null) return const SizedBox.shrink();
        return ValueListenableBuilder<Rect?>(
          valueListenable: controller.rect,
          builder: (context, rect, _) {
            final size = rect == null || rect.width <= 0 || rect.height <= 0
                ? const Size(1920, 1080)
                : rect.size;
            return ClipRect(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: HtmlElementView(
                    viewType: 'com.alexmercerind.media_kit_video.$id',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
