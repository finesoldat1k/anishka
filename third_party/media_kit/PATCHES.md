# media_kit (vendored)

это копия [`media_kit` 1.2.6](https://pub.dev/packages/media_kit) (MIT).
пакет добавлен в репозиторий, потому что для linux нужен один патч,
который нельзя передать через публичный `PlayerConfiguration`.

## изменения

`lib/src/player/native/player/real.dart`, `_create()`:

до `mpv_initialize()` выставляются опции:

```text
load-scripts=no
load-console=no
load-context-menu=no
load-commands=no
load-positioning=no
load-select=no
load-stats-overlay=no
load-auto-profiles=no
ytdl=no
```

## зачем

на некоторых сборках `libmpv` + `luajit` (например, arch linux, mpv 0.41)
встроенный `console.lua` падает с `SIGSEGV` в потоке `lua/console` при
открытии hls. приложению не нужны встроенные скрипты mpv: у него свои
контролы, очередь серий и переключение качества. поэтому скрипты
отключаются до инициализации libmpv.

`ytdl` выключен, потому что приложение открывает прямые hls-ссылки
anilibria и не использует youtube-dl.

## обновление

при обновлении `media_kit` нужно скопировать новую версию пакета,
повторить патч в `_create()` и обновить версию в `pubspec.yaml`.
