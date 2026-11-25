# media_kit_video (vendored)

это копия [`media_kit_video` 2.0.1](https://pub.dev/packages/media_kit_video) (MIT).
пакет добавлен в репозиторий, потому что для linux нужен патч рендера,
который нельзя передать через публичный `VideoControllerConfiguration`.

## изменения

`linux/video_output.cc`, `video_output_new()`:

вместо `eglGetCurrentContext()` создаётся отдельный egl-контекст:

```text
eglGetDisplay(EGL_DEFAULT_DISPLAY)
eglInitialize
eglChooseConfig (pbuffer, GLES2)
eglCreateContext
eglCreatePbufferSurface
eglMakeCurrent
mpv_render_context_create
eglMakeCurrent(EGL_NO_*)
```

контекст не шарится с flutter: `texture_gl.cc` сам делает его current
на raster-потоке, рендерит кадр mpv в fbo и возвращает контекст flutter.

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

`eglGetPlatformDisplay` здесь не используется: epoxy на arch linux не
экспортирует эту функцию, и вызов падает с
`No provider of eglGetPlatformDisplay found`.

## проверка

после запуска видео в stderr должно быть:

```text
media_kit: VideoOutput: H/W rendering with dedicated EGL context.
```

а в свойствах mpv — `hwdec-current=vaapi` (не `vaapi-copy`),
`vo-drop-frame-count` и `mistimed-frame-count` пустые или `0`.
предупреждений `Failed to create fence` быть не должно.

## обновление

при обновлении `media_kit_video` нужно скопировать новую версию пакета,
повторить патч в `video_output_new()` и обновить версию в `pubspec.yaml`.
