# media_kit_video (vendored)

это копия [`media_kit_video` 2.0.1](https://pub.dev/packages/media_kit_video) (MIT).
пакет добавлен в репозиторий, потому что для linux нужен патч рендера,
который нельзя передать через публичный `VideoControllerConfiguration`.

## изменения

`linux/video_output.cc`:

- `video_output_new()` больше не создаёт egl-контекст на platform-потоке.
  он только регистрирует `TextureGL` и запускает таймер, который просит
  flutter вызвать `populate`, пока не появятся настоящие размеры видео.
- новый `video_output_ensure_render_context()` вызывается из
  `TextureGL::populate` на raster-потоке. там egl-контекст flutter уже
  current, поэтому создаётся **общий** с flutter контекст:
  `eglCreateContext(..., flutter_context, ...)`. в нём же создаётся
  `mpv_render_context`.
- больше нет отдельного `EGLImage`-моста: mpv рендерит в fbo, а текстура
  этого fbo сразу видна flutter, потому что контексты sharing-группы.

`linux/texture_gl.cc`:

- `populate` делает общий egl-контекст current, создаёт/ресайзит fbo и
  текстуру, вызывает `mpv_render_context_render()` и возвращает текстуру
  flutter.
- пока mpv не знает размеров кадра, рендер идёт в поверхность 1×1.
  первый `render()` заставляет mpv сконфигурировать video output и начать
  декодирование; после этого приходят реальные `dw`/`dh`.
- нулевые размеры в `VideoOutput.Resize` не отправляются: flutter
  размонтирует `Texture` при rect 0×0, а размонтированная текстура на
  linux перестаёт получать `populate`, и рендер зависает навсегда.

`lib/src/video/video_texture.dart`:

- на linux `Texture` монтируется, как только известен `rect`, даже если
  `player.state.width/height` ещё `null`. это нужно, чтобы первый
  `populate` вообще случился и создал `mpv_render_context`. текстура 1×1
  скрыта штатной чёрной подложкой до первого кадра.

## зачем

в 2.0.1 `video_output_new()` вызывается на platform-потоке gtk, где
egl-контекст flutter не current. `eglGetCurrentContext()` возвращает
`EGL_NO_CONTEXT`, и пакет молча уходит в software rendering:

```text
media_kit: VideoOutput: EGL display or context is invalid.
media_kit: VideoOutput: S/W rendering.
```

при этом `hwdec-current=vaapi-copy`, видео декодируется на gpu, но каждый
кадр копируется в память и рисуется программно. на 1080p это даёт
регулярные подфризы почти каждый кадр, и настройки декодера в приложении
ни на что не влияют.

отдельный egl-контекст без sharing тоже не подходит: mpv рисует в свою
текстуру, а flutter её не видит. попытка импортировать её через
`EGLImage` даёт чёрный экран или искажённые цвета. рабочий вариант —
только общий контекст, созданный на raster-потоке.

`eglGetPlatformDisplay` здесь не используется: epoxy на arch linux не
экспортирует эту функцию, и вызов падает с
`No provider of eglGetPlatformDisplay found`.

## проверка

после запуска видео в stderr должно быть:

```text
media_kit: VideoOutput: H/W rendering.
```

а в свойствах mpv — `hwdec-current=vaapi` (не `vaapi-copy`),
`vo-drop-frame-count` и `mistimed-frame-count` пустые или `0`.
предупреждений `Failed to create fence` быть не должно, картинка должна
быть цветной и не вверх ногами.

## обновление

при обновлении `media_kit_video` нужно скопировать новую версию пакета,
повторить патчи в `linux/video_output.cc`, `linux/texture_gl.cc` и
`lib/src/video/video_texture.dart`, затем обновить версию в
`pubspec.yaml`.
