import 'package:material_ui/material_ui.dart';

import 'trailer_view_stub.dart'
    if (dart.library.io) 'trailer_view_io.dart'
    if (dart.library.html) 'trailer_view_web.dart'
    as impl;

/// Встроенный трейлер с youtube.
///
/// На web рендерится как настоящий `<iframe>`. В режиме [ambient] ролик
/// идёт без звука, без управления и зацикливается — это фоновый трейлер.
/// В интерактивном режиме включаются звук и стандартные контролы.
/// На нативных платформах возвращает пустой виджет: там трейлер
/// открывается в браузере.
class TrailerView extends StatelessWidget {
  const TrailerView({super.key, required this.youtubeId, this.ambient = true});

  final String youtubeId;
  final bool ambient;

  @override
  Widget build(BuildContext context) {
    return impl.buildTrailerView(youtubeId, ambient: ambient);
  }
}
