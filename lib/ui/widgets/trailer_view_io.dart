import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;

/// Native ambient trailer.
///
/// Extracts a progressive stream from YouTube once and hands it to
/// `media_kit`, muted and looped. If extraction fails (offline, changed
/// signature, throttling) the widget stays transparent and the poster below
/// keeps the hero looking alive.
Widget buildTrailerView(String youtubeId, {bool ambient = true}) {
  return _NativeTrailer(youtubeId: youtubeId);
}

class _NativeTrailer extends StatefulWidget {
  const _NativeTrailer({required this.youtubeId});

  final String youtubeId;

  @override
  State<_NativeTrailer> createState() => _NativeTrailerState();
}

class _NativeTrailerState extends State<_NativeTrailer> {
  Player? _player;
  VideoController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _disposed = false;

  /// Invalidates in-flight initialization when the trailer changes or the
  /// widget goes away, so a slow extraction can never revive a dead player.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant _NativeTrailer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeId != widget.youtubeId) {
      _generation++;
      unawaited(_disposePlayer());
      _ready = false;
      _failed = false;
      unawaited(_initialize());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  bool _isStale(int generation) =>
      _disposed || !mounted || generation != _generation;

  void _syncPlayback() {
    final player = _player;
    if (player == null || !_ready) return;
    if (TickerMode.valuesOf(context).enabled) {
      unawaited(player.play());
    } else {
      unawaited(player.pause());
    }
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(widget.youtubeId)
          .timeout(const Duration(seconds: 12));
      final stream = manifest.muxed.withHighestBitrate();
      if (_isStale(generation)) return;

      final streamUrl = stream.url.toString();
      final cacheKey = 'anishka-trailer-${widget.youtubeId}.mp4';
      final cache = DefaultCacheManager();
      final cachedInfo = await cache.getFileFromCache(cacheKey);
      final cachedPath = cachedInfo != null && await cachedInfo.file.exists()
          ? cachedInfo.file.path
          : null;
      if (_isStale(generation)) return;

      final player = Player();
      final controller = VideoController(player);
      if (_isStale(generation)) {
        await player.dispose();
        return;
      }
      _player = player;
      _controller = controller;

      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.open(Media(cachedPath ?? streamUrl));
      if (cachedPath == null) {
        // Keep the stream playing immediately and warm the disk cache for the
        // next visit in the background.
        unawaited(
          cache
              .downloadFile(streamUrl, key: cacheKey)
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
      if (_isStale(generation)) {
        if (identical(_player, player)) {
          _player = null;
          _controller = null;
        }
        await player.dispose();
        return;
      }
      setState(() => _ready = true);
      _syncPlayback();
    } catch (_) {
      if (!_isStale(generation)) setState(() => _failed = true);
    } finally {
      yt.close();
    }
  }

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    _controller = null;
    await player?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_disposePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !_ready) {
      return const SizedBox.expand();
    }
    return SizedBox.expand(
      child: Video(
        controller: controller,
        controls: NoVideoControls,
        fit: BoxFit.cover,
        fill: Colors.transparent,
        wakelock: false,
        pauseUponEnteringBackgroundMode: true,
        resumeUponEnteringForegroundMode: true,
      ),
    );
  }
}
