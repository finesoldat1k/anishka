import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anishka/core/storage/playback_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PlaybackSettingsStore> createStore([
    Map<String, Object>? values,
  ]) async {
    SharedPreferences.setMockInitialValues(values ?? {});
    final prefs = await SharedPreferences.getInstance();
    return PlaybackSettingsStore(prefs);
  }

  test('starts with safe defaults', () async {
    final store = await createStore();

    expect(store.decoder, VideoDecoderPreset.auto);
    expect(store.buffer, VideoBufferPreset.standard);
    expect(store.quality, VideoQualityPreference.auto);
    expect(store.hwdec, 'auto');
    expect(store.hardwareAcceleration, isTrue);
    expect(store.bufferBytes, 32 * 1024 * 1024);
    expect(store.cacheSeconds, 10);
  });

  test('persists every preset and restores it', () async {
    final store = await createStore();
    store.setDecoder(VideoDecoderPreset.software);
    store.setBuffer(VideoBufferPreset.maximum);
    store.setQuality(VideoQualityPreference.q720);

    final restored = await createStore({
      'anishka.playback.decoder.v1': VideoDecoderPreset.software.name,
      'anishka.playback.buffer.v1': VideoBufferPreset.maximum.name,
      'anishka.playback.quality.v1': VideoQualityPreference.q720.name,
    });

    expect(restored.decoder, VideoDecoderPreset.software);
    expect(restored.buffer, VideoBufferPreset.maximum);
    expect(restored.quality, VideoQualityPreference.q720);
    expect(restored.hwdec, 'no');
    expect(restored.hardwareAcceleration, isFalse);
    expect(restored.bufferBytes, 128 * 1024 * 1024);
    expect(restored.cacheSeconds, 60);
  });

  test('preferredQuality follows the preset and falls back sensibly', () async {
    final store = await createStore();

    expect(store.preferredQuality(['1080', '720', '480']), '1080');
    expect(store.preferredQuality(const []), '');

    store.setQuality(VideoQualityPreference.q720);
    expect(store.preferredQuality(['1080', '720', '480']), '720');
    expect(store.preferredQuality(['1080', '480']), '480');
    expect(store.preferredQuality(['480']), '480');

    store.setQuality(VideoQualityPreference.q1080);
    expect(store.preferredQuality(['720', '480']), '720');

    store.setQuality(VideoQualityPreference.q480);
    expect(store.preferredQuality(['1080', '720']), '720');
  });

  test('reset returns to defaults and notifies listeners', () async {
    final store = await createStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    store.setDecoder(VideoDecoderPreset.safe);
    store.setBuffer(VideoBufferPreset.increased);
    store.setQuality(VideoQualityPreference.q480);
    expect(notifications, 3);

    store.reset();
    expect(store.decoder, VideoDecoderPreset.auto);
    expect(store.buffer, VideoBufferPreset.standard);
    expect(store.quality, VideoQualityPreference.auto);
    expect(notifications, 4);
  });

  test('setting the same value does not notify', () async {
    final store = await createStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    store.setDecoder(VideoDecoderPreset.auto);
    store.setBuffer(VideoBufferPreset.standard);
    store.setQuality(VideoQualityPreference.auto);

    expect(notifications, 0);
  });
}
