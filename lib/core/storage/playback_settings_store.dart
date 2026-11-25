import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How libmpv should decode video.
///
/// `auto` lets mpv pick a hardware decoder, `safe` only enables hardware
/// decoding paths that are known to work everywhere, `copy` decodes on the GPU
/// and copies frames back (fixes artefacts from direct rendering), and
/// `software` forces CPU decoding for drivers that crash or produce a
/// green/black picture.
enum VideoDecoderPreset {
  auto('авто', 'mpv сам выбирает аппаратное декодирование', 'auto'),
  safe(
    'совместимость',
    'безопасный аппаратный режим для проблемных драйверов',
    'auto-safe',
  ),
  copy(
    'копирование',
    'аппаратное декодирование с копией кадра — убирает артефакты',
    'auto-copy',
  ),
  software(
    'программное (cpu)',
    'всегда декодирует процессором — максимальная совместимость',
    'no',
  );

  const VideoDecoderPreset(this.label, this.description, this.hwdec);

  final String label;
  final String description;
  final String hwdec;

  bool get hardwareAcceleration => this != software;

  static VideoDecoderPreset fromStorage(Object? value) {
    for (final preset in values) {
      if (preset.name == value) return preset;
    }
    return VideoDecoderPreset.auto;
  }
}

/// Demuxer/network cache size. A larger buffer smooths out unstable HLS
/// sources at the cost of a little extra memory and startup latency.
enum VideoBufferPreset {
  standard('стандартный', '32 мб — обычный просмотр', 32, 10),
  increased('увеличенный', '64 мб — нестабильные hls-потоки', 64, 30),
  maximum(
    'максимальный',
    '128 мб — медленная сеть и частые буферизации',
    128,
    60,
  );

  const VideoBufferPreset(
    this.label,
    this.description,
    this.megabytes,
    this.cacheSeconds,
  );

  final String label;
  final String description;
  final int megabytes;

  /// How many seconds of the stream mpv keeps cached ahead of playback.
  final int cacheSeconds;

  int get bytes => megabytes * 1024 * 1024;

  static VideoBufferPreset fromStorage(Object? value) {
    for (final preset in values) {
      if (preset.name == value) return preset;
    }
    return VideoBufferPreset.standard;
  }
}

/// Which quality the player should prefer when a source offers several.
enum VideoQualityPreference {
  auto('авто', 'максимальное доступное качество', null),
  q1080('1080p', 'полное hd, если источник его отдаёт', '1080'),
  q720('720p', 'баланс чёткости и нагрузки', '720'),
  q480('480p', 'меньше трафика и нагрузки на слабых устройствах', '480');

  const VideoQualityPreference(this.label, this.description, this.quality);

  final String label;
  final String description;
  final String? quality;

  static VideoQualityPreference fromStorage(Object? value) {
    for (final preset in values) {
      if (preset.name == value) return preset;
    }
    return VideoQualityPreference.auto;
  }
}

/// Persisted playback preferences shared by the settings screen and player.
class PlaybackSettingsStore extends ChangeNotifier {
  PlaybackSettingsStore(this._prefs) {
    _load();
  }

  static const _decoderKey = 'anishka.playback.decoder.v1';
  static const _bufferKey = 'anishka.playback.buffer.v1';
  static const _qualityKey = 'anishka.playback.quality.v1';

  final SharedPreferences _prefs;

  VideoDecoderPreset _decoder = VideoDecoderPreset.auto;
  VideoBufferPreset _buffer = VideoBufferPreset.standard;
  VideoQualityPreference _quality = VideoQualityPreference.auto;

  VideoDecoderPreset get decoder => _decoder;
  VideoBufferPreset get buffer => _buffer;
  VideoQualityPreference get quality => _quality;

  int get bufferBytes => _buffer.bytes;
  int get cacheSeconds => _buffer.cacheSeconds;
  bool get hardwareAcceleration => _decoder.hardwareAcceleration;
  String get hwdec => _decoder.hwdec;

  void _load() {
    _decoder = VideoDecoderPreset.fromStorage(_prefs.getString(_decoderKey));
    _buffer = VideoBufferPreset.fromStorage(_prefs.getString(_bufferKey));
    _quality = VideoQualityPreference.fromStorage(
      _prefs.getString(_qualityKey),
    );
  }

  void setDecoder(VideoDecoderPreset value) {
    if (_decoder == value) return;
    _decoder = value;
    unawaited(_prefs.setString(_decoderKey, value.name));
    notifyListeners();
  }

  void setBuffer(VideoBufferPreset value) {
    if (_buffer == value) return;
    _buffer = value;
    unawaited(_prefs.setString(_bufferKey, value.name));
    notifyListeners();
  }

  void setQuality(VideoQualityPreference value) {
    if (_quality == value) return;
    _quality = value;
    unawaited(_prefs.setString(_qualityKey, value.name));
    notifyListeners();
  }

  /// Pick the preferred quality from the options offered by an episode.
  ///
  /// `auto` keeps the source order (highest first). An explicit preference
  /// falls back to the closest lower option and then to the highest available,
  /// so a 1080p preference still plays a 720p-only source.
  String preferredQuality(List<String> options) {
    if (options.isEmpty) return '';
    final wanted = _quality.quality;
    if (wanted == null) return options.first;
    if (options.contains(wanted)) return wanted;

    final wantedValue = int.tryParse(wanted) ?? 0;
    final sorted = [...options]
      ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    for (final option in sorted) {
      final value = int.tryParse(option) ?? 0;
      if (value <= wantedValue) return option;
    }
    return sorted.last;
  }

  void reset() {
    _decoder = VideoDecoderPreset.auto;
    _buffer = VideoBufferPreset.standard;
    _quality = VideoQualityPreference.auto;
    unawaited(_prefs.remove(_decoderKey));
    unawaited(_prefs.remove(_bufferKey));
    unawaited(_prefs.remove(_qualityKey));
    notifyListeners();
  }
}
