import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/sources/resolved_stream.dart';
import '../../core/models/anime_episode.dart';
import '../../core/models/anime_release.dart';
import '../../core/models/anime_source.dart';
import '../../core/models/voiceover.dart';
import '../../core/repository/unified_repository.dart';
import '../../core/services/app_services.dart';
import '../../core/storage/library_store.dart';
import '../../core/storage/playback_settings_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/format.dart';
import '../../ui/widgets/embed_frame.dart';
import '../../ui/widgets/gradient_button.dart';
import '../../ui/widgets/video_surface.dart';
import 'episode_picker_sheet.dart';

/// полноэкранный плеер anishka: hls через media_kit и собственные контролы.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.releaseId,
    required this.episodeOrdinal,
    this.voiceId,
    this.source,
  });

  final int releaseId;
  final int episodeOrdinal;
  final String? voiceId;
  final AnimeSource? source;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _hideDelay = Duration(seconds: 3);
  static const _seekStep = Duration(seconds: 10);

  late final UnifiedRepository _repository;
  late final LibraryStore _library;
  late final PlaybackSettingsStore _playbackSettings;
  final _focusNode = FocusNode(debugLabel: 'player');

  Player? _player;
  VideoController? _controller;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  AnimeRelease? _release;
  AnimeEpisode? _episode;
  VoiceoverInfo? _voice;

  bool _loadingRelease = true;
  String? _loadError;
  String? _playerError;

  bool _playing = false;
  bool _buffering = true;
  bool _completed = false;
  bool _controlsVisible = true;
  bool _immersive = false;
  Timer? _hideTimer;

  String _quality = '1080';
  final Map<String, ResolvedStream> _resolvedStreams = {};
  bool _embedFallback = false;
  double _volume = 100;
  double _lastVolume = 80;
  double _rate = 1;
  String? _errorDetails;

  /// Incremented whenever a new playback request starts. Async completions
  /// from older requests are ignored, so quickly switching episodes or
  /// qualities can never overwrite the newest selection.
  int _playbackToken = 0;

  final _position = ValueNotifier<Duration>(Duration.zero);
  final _duration = ValueNotifier<Duration>(Duration.zero);
  final _buffer = ValueNotifier<Duration>(Duration.zero);
  final _dragPosition = ValueNotifier<Duration?>(null);

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _muted => _volume <= 0.01;

  Duration get _totalDuration {
    final known = _duration.value;
    if (known > Duration.zero) return known;
    return _episode?.duration ?? Duration.zero;
  }

  List<AnimeEpisode> get _playableEpisodes =>
      _release?.episodes.where((episode) => episode.hasStream).toList() ??
      const [];

  String _streamKey(AnimeEpisode episode, String quality) =>
      '${episode.id}::$quality';

  /// Whether the completion of an async playback step still belongs to the
  /// latest request.
  bool _isCurrentPlayback(int token) => mounted && token == _playbackToken;

  /// Whether this platform can render the provider player in-app.
  bool _canEmbed(AnimeEpisode episode) =>
      EmbedFrame.isEmbedSupported &&
      episode.embedUrl?.trim().isNotEmpty == true;

  /// Providers that expose only an embed player cannot be fed to media_kit.
  ///
  /// On web the iframe is the primary path (these players send no CORS
  /// headers). On native platforms a direct resolver is tried first; the
  /// embed is used when no resolver exists or resolution fails.
  bool _preferEmbed(AnimeEpisode episode) {
    if (episode.streamUrl != null) return false;
    if (!_canEmbed(episode)) return false;
    if (kIsWeb) return true;
    return !episode.canResolve;
  }

  bool get _isEmbedPlayback =>
      _embedFallback &&
      EmbedFrame.isEmbedSupported &&
      _episode?.embedUrl?.trim().isNotEmpty == true;

  AnimeEpisode? get _previousEpisode {
    final items = _playableEpisodes;
    final index = items.indexWhere((episode) => episode.id == _episode?.id);
    if (index <= 0) return null;
    return items[index - 1];
  }

  AnimeEpisode? get _nextEpisode {
    final items = _playableEpisodes;
    final index = items.indexWhere((episode) => episode.id == _episode?.id);
    if (index < 0 || index >= items.length - 1) return null;
    return items[index + 1];
  }

  @override
  void initState() {
    super.initState();
    _repository = context.read<AppServices>().repository;
    _library = context.read<LibraryStore>();
    _playbackSettings = context.read<PlaybackSettingsStore>();
    if (_isMobile) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
      _immersive = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final player = _player;
    if (player != null) unawaited(player.dispose());
    _position.dispose();
    _duration.dispose();
    _buffer.dispose();
    _dragPosition.dispose();
    if (_isMobile) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingRelease = true;
      _loadError = null;
    });

    try {
      final provided = widget.source;
      if (provided != null) {
        final release = provided.release;
        if (!mounted) return;
        _library.syncSnapshot(release);

        AnimeEpisode? episode;
        for (final item in release.episodes) {
          if (item.ordinal == widget.episodeOrdinal && item.hasStream) {
            episode = item;
            break;
          }
        }
        episode ??= _firstPlayable(release);
        if (episode == null) {
          setState(() {
            _release = release;
            _loadingRelease = false;
            _loadError = release.episodes.isEmpty
                ? 'у этого источника пока нет серий.'
                : 'у этого источника пока нет доступных видео.';
          });
          return;
        }

        final qualities = _qualityOptions(episode);
        final quality = _playbackSettings.preferredQuality(qualities);
        setState(() {
          _release = release;
          _episode = episode;
          _voice = provided.voiceover;
          _quality = quality.isEmpty ? 'auto' : quality;
          _loadingRelease = false;
          _loadError = null;
        });
        await _startPlayback(episode, provided.voiceover, quality: quality);
        return;
      }

      final release = await _repository.release(widget.releaseId);
      if (!mounted) return;
      _library.syncSnapshot(release);

      AnimeEpisode? episode;
      for (final item in release.episodes) {
        if (item.ordinal == widget.episodeOrdinal && item.hasStream) {
          episode = item;
          break;
        }
      }
      if (episode == null) {
        for (final item in release.episodes) {
          if (item.hasStream) {
            episode = item;
            break;
          }
        }
      }

      if (episode == null) {
        setState(() {
          _release = release;
          _loadingRelease = false;
          _loadError = release.episodes.isEmpty
              ? 'у этого релиза пока нет серий.'
              : 'у этого релиза пока нет доступных источников видео.';
        });
        return;
      }

      final voice = voiceoverById(
        release,
        widget.voiceId ?? _library.voiceFor(release.id),
      );
      final qualities = _qualityOptions(episode);
      final quality = _playbackSettings.preferredQuality(qualities);

      setState(() {
        _release = release;
        _episode = episode;
        _voice = voice;
        _quality = quality.isEmpty ? 'auto' : quality;
        _loadingRelease = false;
        _loadError = null;
      });

      await _startPlayback(episode, voice, quality: quality);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRelease = false;
        _loadError = userMessage(error);
      });
    }
  }

  Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = Player(
      configuration: PlayerConfiguration(
        title: 'анишка',
        bufferSize: _playbackSettings.bufferBytes,
      ),
    );
    _player = player;
    _controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        hwdec: _playbackSettings.hwdec,
        enableHardwareAcceleration: _playbackSettings.hardwareAcceleration,
      ),
    );
    _listenTo(player);
    unawaited(_applyPlaybackProperties(player));
    return player;
  }

  /// Push decoder/cache preferences into libmpv. Most of these options can be
  /// changed while a video is playing, so switching a preset in the player
  /// takes effect without reopening the episode.
  Future<void> _applyPlaybackProperties([Player? target]) async {
    final player = target ?? _player;
    if (player == null || kIsWeb) return;

    final buffer = _playbackSettings.bufferBytes;
    final properties = <String, String>{
      'hwdec': _playbackSettings.hwdec,
      'cache': 'yes',
      'cache-secs': '${_playbackSettings.cacheSeconds}',
      'demuxer-readahead-secs': '${_playbackSettings.cacheSeconds}',
      'demuxer-max-bytes': '$buffer',
      'demuxer-max-back-bytes': '${buffer ~/ 2}',
    };
    try {
      // `setProperty` exists on the native player only. Using `dynamic` keeps
      // the web build free of the FFI-only class while `kIsWeb` guards the
      // call at runtime.
      final dynamic native = player.platform;
      for (final entry in properties.entries) {
        try {
          await native.setProperty(entry.key, entry.value);
        } catch (_) {
          // Unknown option on this platform — keep applying the rest.
        }
      }
    } catch (_) {
      // A platform without native mpv properties must not break playback.
    }
  }

  void _listenTo(Player player) {
    final stream = player.stream;

    _subscriptions.add(
      stream.position.listen((value) {
        if (!mounted) return;
        if (_dragPosition.value == null) _position.value = value;
      }),
    );

    _subscriptions.add(
      stream.duration.listen((value) {
        if (!mounted || value <= Duration.zero) return;
        _duration.value = value;
      }),
    );

    _subscriptions.add(
      stream.buffer.listen((value) {
        if (!mounted) return;
        _buffer.value = value;
      }),
    );

    _subscriptions.add(
      stream.playing.listen((value) {
        if (!mounted) return;
        setState(() {
          _playing = value;
          if (!value) _controlsVisible = true;
        });
        if (value) {
          _scheduleHide();
        } else {
          _hideTimer?.cancel();
        }
      }),
    );

    _subscriptions.add(
      stream.buffering.listen((value) {
        if (!mounted) return;
        setState(() => _buffering = value);
      }),
    );

    _subscriptions.add(
      stream.completed.listen((value) {
        if (!mounted) return;
        setState(() {
          _completed = value;
          if (value) _controlsVisible = true;
        });
        if (value) _hideTimer?.cancel();
      }),
    );

    _subscriptions.add(
      stream.volume.listen((value) {
        if (!mounted) return;
        setState(() => _volume = value);
      }),
    );

    _subscriptions.add(
      stream.rate.listen((value) {
        if (!mounted) return;
        setState(() => _rate = value);
      }),
    );

    _subscriptions.add(
      stream.error.listen((value) {
        if (!mounted) return;
        final message = value.trim();
        if (message.isEmpty) return;
        setState(() {
          _playerError = 'не удалось воспроизвести серию.';
          _errorDetails = message;
          _buffering = false;
        });
      }),
    );
  }

  Future<void> _startPlayback(
    AnimeEpisode episode,
    VoiceoverInfo voice, {
    String? quality,
    bool autoplay = true,
  }) async {
    final token = ++_playbackToken;

    if (_preferEmbed(episode)) {
      await _startEmbed(episode, voice, token: token);
      return;
    }

    final qualities = _qualityOptions(episode);
    if (qualities.isEmpty) {
      setState(() {
        _playerError = 'у этой серии нет доступного источника видео.';
        _errorDetails = null;
        _buffering = false;
      });
      return;
    }

    final preferred = _playbackSettings.preferredQuality(qualities);
    final desired = quality ?? (preferred.isEmpty ? _quality : preferred);
    final resolved = qualities.contains(desired) ? desired : qualities.first;

    ResolvedStream? stream;
    final direct = episode.hlsForQuality(resolved);
    if (direct != null && direct.isNotEmpty) {
      stream = ResolvedStream(
        url: direct,
        headers: episode.streamHeaders,
        kind: StreamKind.fromUrl(direct),
      );
    } else {
      stream = _resolvedStreams[_streamKey(episode, resolved)];
    }

    if (stream == null) {
      setState(() {
        _episode = episode;
        _voice = voice;
        _quality = resolved;
        _embedFallback = false;
        _completed = false;
        _playerError = null;
        _errorDetails = null;
        _buffering = true;
      });
      if (!episode.canResolve) {
        if (_canEmbed(episode)) {
          await _startEmbed(episode, voice, token: token);
          return;
        }
        setState(() {
          _playerError = 'у этой серии нет доступного источника видео.';
          _errorDetails = null;
          _buffering = false;
        });
        return;
      }
      stream = await _repository.resolveStreamDetailed(
        episode,
        quality: resolved,
      );
      if (!_isCurrentPlayback(token)) return;
      if (stream == null || !stream.isPlayable) {
        // Resolution failed: keep playback in-app via the embed player when
        // the platform supports it.
        if (_canEmbed(episode)) {
          await _startEmbed(episode, voice, token: token);
          return;
        }
        setState(() {
          _playerError = 'не удалось получить ссылку на видео.';
          _errorDetails = 'источник ${episode.resolverSource} не ответил.';
          _buffering = false;
        });
        return;
      }
      _resolvedStreams[_streamKey(episode, resolved)] = stream;
    }

    if (!_isCurrentPlayback(token)) return;

    setState(() {
      _episode = episode;
      _voice = voice;
      _quality = resolved;
      _embedFallback = false;
      _completed = false;
      _playerError = null;
      _errorDetails = null;
      _buffering = true;
    });
    _position.value = Duration.zero;
    _buffer.value = Duration.zero;
    _dragPosition.value = null;
    _duration.value = episode.duration ?? Duration.zero;

    try {
      final player = _ensurePlayer();
      await player.open(
        Media(stream.url, httpHeaders: stream.headers),
        play: autoplay,
      );
      if (!_isCurrentPlayback(token)) return;
      _library.saveProgress(
        releaseId: widget.releaseId,
        episode: episode.ordinal,
        voice: voice.id,
      );
      _revealControls();
      _focusNode.requestFocus();
    } catch (error) {
      if (!_isCurrentPlayback(token)) return;
      setState(() {
        _playerError = 'не удалось включить серию.';
        _errorDetails = error.toString();
        _buffering = false;
      });
    }
  }

  /// Keep playback in-app using the provider's embedded player.
  Future<void> _startEmbed(
    AnimeEpisode episode,
    VoiceoverInfo voice, {
    int? token,
  }) async {
    token ??= ++_playbackToken;
    final player = _player;
    if (player != null) {
      try {
        await player.pause();
      } catch (_) {
        // The native player may already be disposed.
      }
    }
    if (!_isCurrentPlayback(token)) return;
    setState(() {
      _episode = episode;
      _voice = voice;
      _embedFallback = true;
      _playerError = null;
      _errorDetails = null;
      _buffering = false;
      _completed = false;
      _playing = false;
      _controlsVisible = true;
      _quality = episode.embedLabel ?? 'embed';
    });
    _position.value = Duration.zero;
    _duration.value = episode.duration ?? Duration.zero;
    _library.saveProgress(
      releaseId: widget.releaseId,
      episode: episode.ordinal,
      voice: voice.id,
    );
  }

  AnimeEpisode? _firstPlayable(AnimeRelease release) {
    for (final episode in release.episodes) {
      if (episode.hasStream) return episode;
    }
    return null;
  }

  List<String> _qualityOptions(AnimeEpisode episode) {
    final options = [
      if (episode.hls1080 != null) '1080',
      if (episode.hls720 != null) '720',
      if (episode.hls480 != null) '480',
    ];
    if (options.isEmpty && (episode.streamUrl != null || episode.canResolve)) {
      return ['auto'];
    }
    return options;
  }

  Future<void> _switchQuality(String quality) async {
    if (_isEmbedPlayback) return;
    final episode = _episode;
    if (episode == null || quality == _quality) return;
    final token = ++_playbackToken;
    final position = _position.value;
    final wasPlaying = _playing;

    ResolvedStream? stream;
    final direct = episode.hlsForQuality(quality);
    if (direct != null && direct.isNotEmpty) {
      stream = ResolvedStream(
        url: direct,
        headers: episode.streamHeaders,
        kind: StreamKind.fromUrl(direct),
      );
    } else {
      stream = _resolvedStreams[_streamKey(episode, quality)];
    }

    if (stream == null) {
      if (!episode.canResolve) return;
      stream = await _repository.resolveStreamDetailed(
        episode,
        quality: quality,
      );
      if (!_isCurrentPlayback(token)) return;
      if (stream == null || !stream.isPlayable) {
        setState(() {
          _playerError = 'не удалось переключить качество.';
          _errorDetails = 'источник ${episode.resolverSource} не ответил.';
        });
        return;
      }
      _resolvedStreams[_streamKey(episode, quality)] = stream;
    }

    if (!_isCurrentPlayback(token)) return;
    setState(() {
      _quality = quality;
      _playerError = null;
      _errorDetails = null;
    });

    try {
      final player = _ensurePlayer();
      await player.open(
        Media(stream.url, httpHeaders: stream.headers),
        play: wasPlaying,
      );
      if (!_isCurrentPlayback(token)) return;
      if (position > Duration.zero) {
        await player.seek(position);
      }
      if (!_isCurrentPlayback(token)) return;
      _focusNode.requestFocus();
    } catch (error) {
      if (!_isCurrentPlayback(token)) return;
      setState(() {
        _playerError = 'не удалось переключить качество.';
        _errorDetails = error.toString();
      });
    }
  }

  Future<void> _retryPlayback() async {
    if (_isEmbedPlayback) return;
    final episode = _episode;
    final voice = _voice;
    if (episode == null || voice == null) return;
    _resolvedStreams.removeWhere((key, _) => key.startsWith('${episode.id}::'));
    _embedFallback = false;
    await _startPlayback(episode, voice, quality: _quality);
  }

  Future<void> _togglePlay() async {
    if (_isEmbedPlayback) return;
    final player = _player;
    if (player == null) {
      await _retryPlayback();
      return;
    }
    if (_playerError != null) {
      await _retryPlayback();
      return;
    }
    if (_completed) {
      await _replay();
      return;
    }
    if (_playing) {
      await player.pause();
    } else {
      await player.play();
    }
    _revealControls();
  }

  Future<void> _replay() async {
    final player = _player;
    if (player == null) return;
    await player.seek(Duration.zero);
    await player.play();
    if (!mounted) return;
    setState(() {
      _completed = false;
      _playerError = null;
    });
    _revealControls();
  }

  Future<void> _seekTo(Duration target) async {
    final player = _player;
    if (player == null) return;
    final total = _totalDuration;
    var milliseconds = target.inMilliseconds;
    if (milliseconds < 0) milliseconds = 0;
    if (total > Duration.zero) {
      milliseconds = math.min(milliseconds, total.inMilliseconds);
    }
    final resolved = Duration(milliseconds: milliseconds);
    _position.value = resolved;
    await player.seek(resolved);
  }

  Future<void> _seekRelative(Duration delta) async {
    await _seekTo(_position.value + delta);
  }

  Future<void> _playEpisode(AnimeEpisode episode) async {
    final voice = _voice;
    if (voice == null) return;
    await _startPlayback(episode, voice);
  }

  Future<void> _openEpisodePicker() async {
    final release = _release;
    final voice = _voice;
    if (release == null || voice == null) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);

    final selected = await showEpisodePickerSheet(
      context,
      episodes: release.episodes,
      voiceTitle: voice.title,
      currentOrdinal: _episode?.ordinal,
    );
    if (!mounted) return;
    _revealControls();
    _focusNode.requestFocus();
    if (selected == null) return;
    if (selected.ordinal == _episode?.ordinal) {
      if (_playerError != null) await _retryPlayback();
      return;
    }
    await _startPlayback(selected, voice);
  }

  Future<void> _openPlaybackSettings() async {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    final episode = _episode;
    final qualities = episode == null
        ? const <String>[]
        : _qualityOptions(episode);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (context) => _PlaybackSettingsSheet(
        settings: _playbackSettings,
        qualities: qualities,
        currentQuality: _quality,
        onChanged: () => unawaited(_applyPlaybackProperties()),
        onQualitySelected: (value) {
          if (_isEmbedPlayback) return;
          if (qualities.contains(value) && value != _quality) {
            unawaited(_switchQuality(value));
          }
        },
      ),
    );
    if (!mounted) return;
    _revealControls();
    _focusNode.requestFocus();
  }

  Future<void> _setVolume(double value) async {
    final clamped = value.clamp(0.0, 100.0).toDouble();
    if (clamped > 0) _lastVolume = clamped;
    setState(() => _volume = clamped);
    final player = _player;
    if (player != null) await player.setVolume(clamped);
  }

  Future<void> _toggleMute() async {
    if (_volume > 0.01) {
      _lastVolume = _volume;
      await _setVolume(0);
    } else {
      await _setVolume(_lastVolume <= 0 ? 60 : _lastVolume);
    }
  }

  Future<void> _setRate(double rate) async {
    final player = _player;
    if (player == null) return;
    setState(() => _rate = rate);
    await player.setRate(rate);
  }

  Future<void> _toggleImmersive() async {
    if (!_isMobile) return;
    final next = !_immersive;
    setState(() => _immersive = next);
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    _revealControls();
  }

  void _revealControls() {
    _hideTimer?.cancel();
    if (!mounted) return;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing || _completed || _playerError != null) return;
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted) return;
      if (!_playing) return;
      setState(() => _controlsVisible = false);
    });
  }

  Future<void> _openExternal() async {
    final url = _episode?.embedUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('не удалось открыть внешний плеер')),
      );
    }
  }

  void _goBack() {
    final episode = _episode;
    if (episode != null) {
      _library.saveProgress(
        releaseId: widget.releaseId,
        episode: episode.ordinal,
        voice: _voice?.id ?? defaultVoiceoverId,
      );
    }
    _hideTimer?.cancel();
    if (context.canPop()) {
      context.pop();
    } else {
      final shikimoriId = widget.source?.shikimoriAnime.id ?? 0;
      context.go(shikimoriId > 0 ? '/anime/shikimori/$shikimoriId' : '/');
    }
  }

  ({String label, Duration target})? _skipHint(Duration position) {
    final episode = _episode;
    if (episode == null) return null;
    final openingStart = episode.openingStartDuration;
    final openingStop = episode.openingStopDuration;
    if (openingStart != null &&
        openingStop != null &&
        openingStop > openingStart &&
        position >= openingStart &&
        position < openingStop - const Duration(seconds: 1)) {
      return (label: 'пропустить опенинг', target: openingStop);
    }
    final endingStart = episode.endingStartDuration;
    final endingStop = episode.endingStopDuration;
    if (endingStart != null &&
        endingStop != null &&
        endingStop > endingStart &&
        position >= endingStart &&
        position < endingStop - const Duration(seconds: 1)) {
      return (label: 'пропустить концовку', target: endingStop);
    }
    return null;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (_immersive) {
        unawaited(_toggleImmersive());
      } else {
        _goBack();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (repeat) return KeyEventResult.handled;
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seekRelative(-_seekStep));
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seekRelative(_seekStep));
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      unawaited(_setVolume(_volume + 5));
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      unawaited(_setVolume(_volume - 5));
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      unawaited(_toggleMute());
      _revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      unawaited(_toggleImmersive());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN || key == LogicalKeyboardKey.keyP) {
      final target = key == LogicalKeyboardKey.keyN
          ? _nextEpisode
          : _previousEpisode;
      if (target != null) unawaited(_playEpisode(target));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    final episode = _episode;
    final controller = _controller;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 640;

    if (_isEmbedPlayback && !_loadingRelease && _loadError == null) {
      final embedEpisode = episode!;
      return _EmbedPlayerScaffold(
        title: release?.displayTitle ?? '',
        episodeLabel:
            '${embedEpisode.displayName} · ${_voice?.title ?? 'озвучка'}',
        playerLabel: embedEpisode.embedLabel ?? '',
        embedUrl: embedEpisode.embedUrl!,
        onBack: _goBack,
        onEpisodes: _openEpisodePicker,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          onHover: (_) => _revealControls(),
          cursor: _controlsVisible
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              // On web the video is an HTML element that paints above the
              // Flutter canvas. Removing it while an error/loading overlay is
              // visible keeps the card clickable instead of hiding it behind
              // the video surface.
              if (controller != null &&
                  !_loadingRelease &&
                  _loadError == null &&
                  _playerError == null)
                Center(child: VideoSurface(controller: controller)),
              // Overlays are placed after the video surface and the error card
              // is the last child, so it wins hit-testing above the controls.
              // The video element itself is removed while an error is visible:
              // HTML platform views paint above Flutter widgets on web.
              if (_loadingRelease)
                _PlayerLoading(onBack: _goBack)
              else if (_loadError != null)
                _PlayerLoadError(
                  message: _loadError!,
                  onRetry: () => unawaited(_bootstrap()),
                  onBack: _goBack,
                )
              else ...[
                _SkipButton(
                  position: _position,
                  hintFor: _skipHint,
                  onSkip: (target) => unawaited(_seekTo(target)),
                  raised: _controlsVisible,
                ),
                _TopBar(
                  visible: _controlsVisible,
                  compact: compact,
                  title: release?.displayTitle ?? '',
                  episodeLabel: episode == null
                      ? ''
                      : '${episode.displayName} · ${_voice?.title ?? 'озвучка'}',
                  quality: _quality,
                  qualities: episode == null
                      ? const []
                      : _qualityOptions(episode),
                  onBack: _goBack,
                  onQuality: (value) => unawaited(_switchQuality(value)),
                  onEpisodes: _openEpisodePicker,
                  onSettings: () => unawaited(_openPlaybackSettings()),
                ),
                _BottomBar(
                  visible: _controlsVisible,
                  compact: compact,
                  playing: _playing,
                  hasPrevious: _previousEpisode != null,
                  hasNext: _nextEpisode != null,
                  muted: _muted,
                  volume: _volume,
                  rate: _rate,
                  immersive: _immersive,
                  showImmersive: _isMobile,
                  position: _position,
                  duration: _duration,
                  buffer: _buffer,
                  dragPosition: _dragPosition,
                  fallbackDuration: episode?.duration ?? Duration.zero,
                  onTogglePlay: _togglePlay,
                  onPrevious: _previousEpisode == null
                      ? null
                      : () => unawaited(_playEpisode(_previousEpisode!)),
                  onNext: _nextEpisode == null
                      ? null
                      : () => unawaited(_playEpisode(_nextEpisode!)),
                  onSeekBack: () => _seekRelative(-_seekStep),
                  onSeekForward: () => _seekRelative(_seekStep),
                  onVolume: (value) => unawaited(_setVolume(value)),
                  onToggleMute: _toggleMute,
                  onRate: (value) => unawaited(_setRate(value)),
                  onImmersive: _toggleImmersive,
                  onSeekStart: () {
                    _hideTimer?.cancel();
                  },
                  onSeekChanged: (value) {
                    _dragPosition.value = value;
                  },
                  onSeekEnd: (value) async {
                    await _seekTo(value);
                    _dragPosition.value = null;
                    _revealControls();
                  },
                ),
                _CenterOverlay(
                  playing: _playing,
                  buffering: _buffering,
                  completed: _completed,
                  error: _playerError,
                  errorDetails: _errorDetails,
                  controlsVisible: _controlsVisible,
                  onPlay: _togglePlay,
                  onReplay: _replay,
                  onRetry: _retryPlayback,
                  onExternal:
                      !EmbedFrame.isEmbedSupported &&
                          episode?.embedUrl?.isNotEmpty == true
                      ? () => unawaited(_openExternal())
                      : null,
                  onNext: _nextEpisode == null
                      ? null
                      : () => unawaited(_playEpisode(_nextEpisode!)),
                  onPickEpisode: _openEpisodePicker,
                  nextLabel: _nextEpisode == null
                      ? null
                      : 'серия ${_nextEpisode!.ordinal}',
                  onSettings: () => unawaited(_openPlaybackSettings()),
                  onEmbed:
                      !_isEmbedPlayback &&
                          episode != null &&
                          _voice != null &&
                          _canEmbed(episode)
                      ? () => unawaited(_startEmbed(episode, _voice!))
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Layout for provider-embedded playback.
///
/// The iframe sits below a solid header instead of under a translucent
/// overlay: HTML platform views are rendered by the browser above Flutter's
/// canvas, so stacking controls on top of them is unreliable.
class _EmbedPlayerScaffold extends StatelessWidget {
  const _EmbedPlayerScaffold({
    required this.title,
    required this.episodeLabel,
    required this.playerLabel,
    required this.embedUrl,
    required this.onBack,
    required this.onEpisodes,
  });

  final String title;
  final String episodeLabel;
  final String playerLabel;
  final String embedUrl;
  final VoidCallback onBack;
  final VoidCallback onEpisodes;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          ColoredBox(
            color: AppColors.background,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 10 : 18,
                  8,
                  compact ? 10 : 18,
                  10,
                ),
                child: Row(
                  children: [
                    _IconButton(
                      icon: AppIcons.arrowLeft,
                      tooltip: 'назад',
                      compact: compact,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: -0.3,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            episodeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (playerLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _GlassPill(
                        label: playerLabel,
                        icon: AppIcons.plugs,
                        compact: compact,
                      ),
                    ],
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: AppIcons.filmStrip,
                      tooltip: 'выбрать серию',
                      compact: compact,
                      subtle: true,
                      onTap: onEpisodes,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: EmbedFrame(url: embedUrl, title: title),
          ),
        ],
      ),
    );
  }
}

class _PlaybackSettingsSheet extends StatelessWidget {
  const _PlaybackSettingsSheet({
    required this.settings,
    required this.qualities,
    required this.currentQuality,
    required this.onChanged,
    required this.onQualitySelected,
  });

  final PlaybackSettingsStore settings;
  final List<String> qualities;
  final String currentQuality;
  final VoidCallback onChanged;
  final ValueChanged<String> onQualitySelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: settings,
              builder: (context, _) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppColors.borderStrong,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            AppIcons.speedometer,
                            size: 18,
                            color: AppColors.accentBright,
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'видео',
                              style: TextStyle(
                                fontFamily: AppFonts.display,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                letterSpacing: -0.2,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              settings.reset();
                              onChanged();
                              final target = settings.preferredQuality(
                                qualities,
                              );
                              if (target.isNotEmpty) onQualitySelected(target);
                            },
                            child: const Text(
                              'сбросить',
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'настройки применяются сразу, без перезапуска серии',
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      _sectionTitle('декодирование'),
                      for (final preset in VideoDecoderPreset.values)
                        _option(
                          title: preset.label,
                          subtitle: preset.description,
                          selected: settings.decoder == preset,
                          onTap: () {
                            settings.setDecoder(preset);
                            onChanged();
                          },
                        ),
                      _sectionTitle('буфер'),
                      for (final preset in VideoBufferPreset.values)
                        _option(
                          title: preset.label,
                          subtitle: preset.description,
                          selected: settings.buffer == preset,
                          onTap: () {
                            settings.setBuffer(preset);
                            onChanged();
                          },
                        ),
                      if (qualities.isNotEmpty) ...[
                        _sectionTitle('качество'),
                        for (final preset in VideoQualityPreference.values)
                          _option(
                            title: preset.label,
                            subtitle: preset.quality == null
                                ? 'сейчас: ${_qualityLabel(currentQuality)}'
                                : preset.description,
                            selected: settings.quality == preset,
                            enabled:
                                preset.quality == null ||
                                qualities.contains(preset.quality),
                            onTap: () {
                              settings.setQuality(preset);
                              onChanged();
                              final target = settings.preferredQuality(
                                qualities,
                              );
                              if (target.isNotEmpty) onQualitySelected(target);
                            },
                          ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'если видео дёргается или рассыпается на квадраты — '
                          'включите «совместимость» и увеличенный буфер. '
                          'если картинка зелёная или чёрная — попробуйте '
                          'программное декодирование.',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 10.5,
                            height: 1.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 2),
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.2,
          color: AppColors.textSoft,
        ),
      ),
    );
  }

  Widget _option({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final tone = selected ? AppColors.accentBright : AppColors.textFaint;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : AppColors.surfaceHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.55)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? AppIcons.checkCircle : AppIcons.circle,
                  size: 17,
                  color: tone,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: selected ? AppColors.text : AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.visible,
    required this.compact,
    required this.title,
    required this.episodeLabel,
    required this.quality,
    required this.qualities,
    required this.onBack,
    required this.onQuality,
    required this.onEpisodes,
    required this.onSettings,
  });

  final bool visible;
  final bool compact;
  final String title;
  final String episodeLabel;
  final String quality;
  final List<String> qualities;
  final VoidCallback onBack;
  final ValueChanged<String> onQuality;
  final VoidCallback onEpisodes;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE6000000),
                  Color(0x99000000),
                  Color(0x00000000),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 22,
              8,
              compact ? 12 : 22,
              34,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  _IconButton(
                    icon: AppIcons.arrowLeft,
                    tooltip: 'назад',
                    onTap: onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          episodeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (qualities.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'качество',
                      initialValue: quality,
                      onSelected: onQuality,
                      color: AppColors.surfaceHigh,
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) => [
                        for (final option in qualities)
                          PopupMenuItem<String>(
                            value: option,
                            child: Row(
                              children: [
                                Icon(
                                  option == quality
                                      ? AppIcons.check
                                      : AppIcons.highDefinition,
                                  size: 17,
                                  color: option == quality
                                      ? AppColors.accentBright
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  _qualityLabel(option),
                                  style: const TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 12.5,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      child: _GlassPill(
                        icon: AppIcons.highDefinition,
                        label: _qualityLabel(quality),
                      ),
                    ),
                  const SizedBox(width: 8),
                  _IconButton(
                    icon: AppIcons.speedometer,
                    tooltip: 'настройки видео',
                    onTap: onSettings,
                  ),
                  const SizedBox(width: 8),
                  _IconButton(
                    icon: AppIcons.filmStrip,
                    tooltip: 'выбрать серию',
                    onTap: onEpisodes,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.visible,
    required this.compact,
    required this.playing,
    required this.hasPrevious,
    required this.hasNext,
    required this.muted,
    required this.volume,
    required this.rate,
    required this.immersive,
    required this.showImmersive,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.dragPosition,
    required this.fallbackDuration,
    required this.onTogglePlay,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekBack,
    required this.onSeekForward,
    required this.onVolume,
    required this.onToggleMute,
    required this.onRate,
    required this.onImmersive,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final bool visible;
  final bool compact;
  final bool playing;
  final bool hasPrevious;
  final bool hasNext;
  final bool muted;
  final double volume;
  final double rate;
  final bool immersive;
  final bool showImmersive;
  final ValueNotifier<Duration> position;
  final ValueNotifier<Duration> duration;
  final ValueNotifier<Duration> buffer;
  final ValueNotifier<Duration?> dragPosition;
  final Duration fallbackDuration;
  final Future<void> Function() onTogglePlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Future<void> Function() onSeekBack;
  final Future<void> Function() onSeekForward;
  final ValueChanged<double> onVolume;
  final Future<void> Function() onToggleMute;
  final ValueChanged<double> onRate;
  final Future<void> Function() onImmersive;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekChanged;
  final ValueChanged<Duration> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF2000000),
                  Color(0x99000000),
                  Color(0x00000000),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 26,
              48,
              compact ? 14 : 26,
              10,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SeekRow(
                    position: position,
                    duration: duration,
                    buffer: buffer,
                    dragPosition: dragPosition,
                    fallbackDuration: fallbackDuration,
                    onSeekStart: onSeekStart,
                    onSeekChanged: onSeekChanged,
                    onSeekEnd: onSeekEnd,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: compact ? 78 : 150,
                        child: Row(
                          children: [
                            _IconButton(
                              icon: muted
                                  ? AppIcons.speakerSlash
                                  : AppIcons.speakerHigh,
                              tooltip: muted
                                  ? 'включить звук'
                                  : 'выключить звук',
                              onTap: () => unawaited(onToggleMute()),
                              subtle: true,
                              compact: true,
                            ),
                            if (!compact)
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 4.5,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 11,
                                    ),
                                  ),
                                  child: Slider(
                                    value: volume.clamp(0.0, 100.0).toDouble(),
                                    max: 100,
                                    onChanged: onVolume,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _IconButton(
                              icon: AppIcons.skipBack,
                              tooltip: 'предыдущая серия',
                              onTap: hasPrevious ? onPrevious : null,
                              compact: true,
                            ),
                            SizedBox(width: compact ? 2 : 8),
                            _IconButton(
                              icon: AppIcons.clockCounterClockwise,
                              tooltip: 'назад 10 секунд',
                              onTap: () => unawaited(onSeekBack()),
                              compact: compact,
                            ),
                            SizedBox(width: compact ? 8 : 16),
                            _PlayButton(
                              playing: playing,
                              onTap: () => unawaited(onTogglePlay()),
                              compact: compact,
                            ),
                            SizedBox(width: compact ? 8 : 16),
                            _IconButton(
                              icon: AppIcons.clockClockwise,
                              tooltip: 'вперёд 10 секунд',
                              onTap: () => unawaited(onSeekForward()),
                              compact: compact,
                            ),
                            SizedBox(width: compact ? 2 : 8),
                            _IconButton(
                              icon: AppIcons.skipForward,
                              tooltip: 'следующая серия',
                              onTap: hasNext ? onNext : null,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: compact ? 78 : 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PopupMenuButton<double>(
                              tooltip: 'скорость',
                              initialValue: rate,
                              onSelected: onRate,
                              color: AppColors.surfaceHigh,
                              position: PopupMenuPosition.under,
                              itemBuilder: (context) => [
                                for (final option in const [
                                  0.75,
                                  1.0,
                                  1.25,
                                  1.5,
                                  2.0,
                                ])
                                  PopupMenuItem<double>(
                                    value: option,
                                    child: Row(
                                      children: [
                                        Icon(
                                          option == rate
                                              ? AppIcons.check
                                              : AppIcons.speedometer,
                                          size: 16,
                                          color: option == rate
                                              ? AppColors.accentBright
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          '${_formatRate(option)}x',
                                          style: const TextStyle(
                                            fontFamily: AppFonts.body,
                                            fontSize: 12.5,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              child: _GlassPill(
                                label: '${_formatRate(rate)}x',
                                compact: true,
                              ),
                            ),
                            if (showImmersive) ...[
                              const SizedBox(width: 4),
                              _IconButton(
                                icon: immersive
                                    ? AppIcons.cornersIn
                                    : AppIcons.cornersOut,
                                tooltip: immersive
                                    ? 'выйти из полного экрана'
                                    : 'полный экран',
                                onTap: () => unawaited(onImmersive()),
                                subtle: true,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekRow extends StatelessWidget {
  const _SeekRow({
    required this.position,
    required this.duration,
    required this.buffer,
    required this.dragPosition,
    required this.fallbackDuration,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final ValueNotifier<Duration> position;
  final ValueNotifier<Duration> duration;
  final ValueNotifier<Duration> buffer;
  final ValueNotifier<Duration?> dragPosition;
  final Duration fallbackDuration;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekChanged;
  final ValueChanged<Duration> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: position,
      builder: (context, current, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: duration,
          builder: (context, known, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: buffer,
              builder: (context, buffered, _) {
                return ValueListenableBuilder<Duration?>(
                  valueListenable: dragPosition,
                  builder: (context, dragging, _) {
                    final total = known > Duration.zero
                        ? known
                        : fallbackDuration;
                    final totalMs = total.inMilliseconds;
                    final shown = dragging ?? current;
                    final valueMs = totalMs <= 0
                        ? 0.0
                        : shown.inMilliseconds.clamp(0, totalMs).toDouble();
                    final bufferMs = totalMs <= 0
                        ? 0.0
                        : math
                              .max(buffered.inMilliseconds, valueMs.round())
                              .clamp(0, totalMs)
                              .toDouble();

                    return Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            formatDuration(shown),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSoft,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              secondaryActiveTrackColor: Colors.white
                                  .withValues(alpha: 0.20),
                            ),
                            child: Slider(
                              value: valueMs,
                              max: totalMs <= 0 ? 1 : totalMs.toDouble(),
                              secondaryTrackValue: bufferMs,
                              onChangeStart: totalMs <= 0
                                  ? null
                                  : (value) {
                                      onSeekStart();
                                      onSeekChanged(
                                        Duration(milliseconds: value.round()),
                                      );
                                    },
                              onChanged: totalMs <= 0
                                  ? null
                                  : (value) => onSeekChanged(
                                      Duration(milliseconds: value.round()),
                                    ),
                              onChangeEnd: totalMs <= 0
                                  ? null
                                  : (value) => onSeekEnd(
                                      Duration(milliseconds: value.round()),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 52,
                          child: Text(
                            totalMs <= 0 ? '—:—' : formatDuration(total),
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.position,
    required this.hintFor,
    required this.onSkip,
    required this.raised,
  });

  final ValueNotifier<Duration> position;
  final ({String label, Duration target})? Function(Duration position) hintFor;
  final ValueChanged<Duration> onSkip;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: position,
      builder: (context, value, _) {
        final hint = hintFor(value);
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          right: 24,
          bottom: raised ? 118 : 28,
          child: AnimatedOpacity(
            opacity: hint == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: hint == null,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: hint == null ? null : () => onSkip(hint.target),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hint?.label ?? '',
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          AppIcons.skipForward,
                          size: 17,
                          color: AppColors.accentBright,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CenterOverlay extends StatelessWidget {
  const _CenterOverlay({
    required this.playing,
    required this.buffering,
    required this.completed,
    required this.error,
    required this.errorDetails,
    required this.controlsVisible,
    required this.onPlay,
    required this.onReplay,
    required this.onRetry,
    required this.onNext,
    required this.onPickEpisode,
    required this.nextLabel,
    required this.onSettings,
    required this.onEmbed,
    this.onExternal,
  });

  final bool playing;
  final bool buffering;
  final bool completed;
  final String? error;
  final String? errorDetails;
  final bool controlsVisible;
  final Future<void> Function() onPlay;
  final Future<void> Function() onReplay;
  final Future<void> Function() onRetry;
  final VoidCallback? onNext;
  final VoidCallback onPickEpisode;
  final String? nextLabel;
  final VoidCallback onSettings;
  final VoidCallback? onEmbed;
  final VoidCallback? onExternal;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _CenterCard(
        icon: AppIcons.warningCircle,
        title: error!,
        message: errorDetails == null
            ? 'проверьте соединение и попробуйте ещё раз.'
            : lc(errorDetails).split('\n').first,
        actions: [
          GradientButton(
            label: 'попробовать снова',
            icon: AppIcons.arrowClockwise,
            onTap: () => unawaited(onRetry()),
            height: 44,
          ),
          GradientButton(
            label: 'выбрать серию',
            icon: AppIcons.filmStrip,
            ghost: true,
            onTap: onPickEpisode,
            height: 44,
          ),
          GradientButton(
            label: 'настройки видео',
            icon: AppIcons.speedometer,
            ghost: true,
            onTap: onSettings,
            height: 44,
          ),
          if (onEmbed != null)
            GradientButton(
              label: 'встроенный плеер',
              icon: AppIcons.playCircle,
              ghost: true,
              onTap: onEmbed!,
              height: 44,
            ),
          if (onExternal != null)
            GradientButton(
              label: 'открыть в браузере',
              icon: AppIcons.arrowSquareOut,
              ghost: true,
              onTap: onExternal!,
              height: 44,
            ),
        ],
      );
    }

    if (completed) {
      return _CenterCard(
        icon: AppIcons.checkCircle,
        title: 'серия завершена',
        message: 'можно пересмотреть или сразу перейти к следующей.',
        actions: [
          GradientButton(
            label: 'пересмотреть',
            icon: AppIcons.arrowCounterClockwise,
            onTap: () => unawaited(onReplay()),
            height: 44,
          ),
          if (onNext != null && nextLabel != null)
            GradientButton(
              label: 'смотреть $nextLabel',
              icon: AppIcons.play,
              ghost: true,
              onTap: onNext,
              height: 44,
            ),
        ],
      );
    }

    if (buffering && !playing) {
      return const Center(child: _BufferingBadge());
    }

    if (!playing) {
      return Center(
        child: AnimatedOpacity(
          opacity: controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: _PlayButton(
            playing: false,
            onTap: () => unawaited(onPlay()),
            compact: false,
            big: true,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _BufferingBadge extends StatelessWidget {
  const _BufferingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentBright,
            ),
          ),
          SizedBox(width: 11),
          Text(
            'буферизация',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: AppColors.backgroundLift.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 44,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.10),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(icon, color: AppColors.accentBright, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title.toLowerCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.toLowerCase(),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(height: 18),
                Text(
                  'загружаем серию',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    letterSpacing: -0.2,
                    color: AppColors.textSoft.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _IconButton(
                  icon: AppIcons.arrowLeft,
                  tooltip: 'назад',
                  onTap: onBack,
                  subtle: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerLoadError extends StatelessWidget {
  const _PlayerLoadError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          Center(
            child: _CenterCard(
              icon: AppIcons.cloudSlash,
              title: 'не удалось открыть серию',
              message: message,
              actions: [
                GradientButton(
                  label: 'попробовать снова',
                  icon: AppIcons.arrowClockwise,
                  onTap: onRetry,
                  height: 44,
                ),
                GradientButton(
                  label: 'назад',
                  icon: AppIcons.arrowLeft,
                  ghost: true,
                  onTap: onBack,
                  height: 44,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _IconButton(
                  icon: AppIcons.arrowLeft,
                  tooltip: 'назад',
                  onTap: onBack,
                  subtle: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label, this.icon, this.compact = false});

  final String label;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 30 : 34,
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.textSoft),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10.5 : 11,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.compact = false,
    this.subtle = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool compact;
  final bool subtle;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _pressController.forward();
      setState(() => _pressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 34.0 : 40.0;
    final enabled = widget.onTap != null;
    final bgColor = widget.subtle
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.white.withValues(alpha: 0.09);
    final hoverColor = widget.subtle
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.16);
    final borderColor = Colors.white.withValues(
      alpha: widget.subtle ? 0.08 : 0.14,
    );

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) {
          setState(() => _hovered = false);
          if (_pressed) {
            _pressController.reverse();
            setState(() => _pressed = false);
          }
        },
        child: ScaleTransition(
          scale: _pressAnimation,
          child: Material(
            color: _hovered ? hoverColor : bgColor,
            shape: CircleBorder(side: BorderSide(color: borderColor)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  widget.icon,
                  size: widget.compact ? 19 : 21,
                  color: enabled
                      ? (_hovered ? AppColors.text : AppColors.textSoft)
                      : AppColors.textFaint.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.playing,
    required this.onTap,
    required this.compact,
    this.big = false,
  });

  final bool playing;
  final VoidCallback onTap;
  final bool compact;
  final bool big;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 76.0 : (widget.compact ? 48.0 : 56.0);

    return Tooltip(
      message: widget.playing ? 'пауза' : 'воспроизвести',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ScaleTransition(
          scale: _pressAnimation,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.42),
                      blurRadius: widget.big ? 34 : 20,
                      spreadRadius: widget.big ? 4 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  widget.playing ? AppIcons.pause : AppIcons.play,
                  size: widget.big ? 42 : (widget.compact ? 27 : 32),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _qualityLabel(String quality) => switch (quality) {
  'auto' => 'авто',
  'embed' => 'embed',
  _ => '${quality}p',
};

String _formatRate(double value) {
  final hundredths = (value * 100).round();
  if (hundredths % 100 == 0) return '${hundredths ~/ 100}';
  if (hundredths % 10 == 0) return (hundredths / 100).toStringAsFixed(1);
  return (hundredths / 100).toStringAsFixed(2);
}
