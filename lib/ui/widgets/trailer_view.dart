import 'package:material_ui/material_ui.dart';

import 'trailer_view_stub.dart'
    if (dart.library.html) 'trailer_view_web.dart' as impl;

/// Встроенный трейлер с youtube.
///
/// На web рендерится как настоящий `<iframe>` поверх баннера, поэтому
/// ролик запускается без звука и зацикливается. На нативных платформах
/// возвращает пустой виджет: там трейлер открывается в браузере.
class TrailerView extends StatelessWidget {
  const TrailerView({super.key, required this.youtubeId});

  final String youtubeId;

  @override
  Widget build(BuildContext context) {
    return impl.buildTrailerView(youtubeId);
  }
}
