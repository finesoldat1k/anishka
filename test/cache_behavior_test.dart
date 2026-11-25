import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anishka/core/cache/persistent_cache.dart';
import 'package:anishka/core/cache/unified_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnifiedCache', () {
    test('deduplicates concurrent loads', () async {
      final cache = UnifiedCache();
      var calls = 0;

      Future<int> load() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 7;
      }

      final results = await Future.wait([
        cache.getOrLoad('key', load, ttl: const Duration(minutes: 1)),
        cache.getOrLoad('key', load, ttl: const Duration(minutes: 1)),
      ]);

      expect(results, [7, 7]);
      expect(calls, 1);
    });

    test('deduplicates concurrent force refreshes', () async {
      final cache = UnifiedCache();
      var calls = 0;

      Future<int> load() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return calls;
      }

      final results = await Future.wait([
        cache.getOrLoad(
          'key',
          load,
          ttl: const Duration(minutes: 1),
          forceRefresh: true,
        ),
        cache.getOrLoad(
          'key',
          load,
          ttl: const Duration(minutes: 1),
          forceRefresh: true,
        ),
      ]);

      expect(results, [1, 1]);
      expect(calls, 1);
    });

    test('expires entries after their ttl', () async {
      final cache = UnifiedCache();
      var calls = 0;

      Future<String> load() async => 'v${++calls}';

      expect(
        await cache.getOrLoad(
          'key',
          load,
          ttl: const Duration(milliseconds: 20),
        ),
        'v1',
      );
      expect(
        await cache.getOrLoad(
          'key',
          load,
          ttl: const Duration(milliseconds: 20),
        ),
        'v1',
      );

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        await cache.getOrLoad(
          'key',
          load,
          ttl: const Duration(milliseconds: 20),
        ),
        'v2',
      );
    });

    test('persistent reads preserve the remaining disk ttl', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persistent = PersistentCache(prefs);
      final cache = UnifiedCache()..usePersistent(persistent);

      var calls = 0;
      Future<String> load() async => 'network${++calls}';

      Future<String> read() => cache.getOrLoadPersistent<String>(
            key: 'key',
            loader: load,
            ttl: const Duration(days: 1),
            decoder: (json) => json as String,
            encoder: (value) => value,
          );

      expect(await read(), 'network1');

      // Replace the disk entry with a short-lived one. The long ttl argument
      // must not extend it when the entry is loaded from disk.
      await persistent.writeRaw(
        'key',
        jsonEncode('disk'),
        const Duration(milliseconds: 30),
      );
      cache.invalidate('key');

      expect(await read(), 'disk');
      expect(calls, 1);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await read(), 'network2');
      expect(calls, 2);
    });

    test('invalidation during a load prevents a stale cache write', () async {
      final cache = UnifiedCache();
      var calls = 0;
      final gate = Completer<void>();

      Future<int> load() async {
        calls++;
        await gate.future;
        return calls;
      }

      final first = cache.getOrLoad(
        'key',
        load,
        ttl: const Duration(minutes: 1),
      );
      cache.invalidate('key');
      gate.complete();

      expect(await first, 1);
      expect(cache.get<int>('key'), isNull);
      expect(
        await cache.getOrLoad(
          'key',
          () async => 2,
          ttl: const Duration(minutes: 1),
        ),
        2,
      );
    });

    test('drops corrupted disk entries and falls back to the loader', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persistent = PersistentCache(prefs);
      final cache = UnifiedCache()..usePersistent(persistent);

      await persistent.writeRaw(
        'key',
        'not-json',
        const Duration(days: 1),
      );

      final value = await cache.getOrLoadPersistent<Map<String, dynamic>>(
        key: 'key',
        loader: () async => {'ok': true},
        ttl: const Duration(days: 1),
        decoder: (json) => json as Map<String, dynamic>,
        encoder: (value) => value,
      );

      expect(value, {'ok': true});
      expect(cache.hasFresh('key'), isTrue);
    });

    test('fresh memory value wins over the disk layer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persistent = PersistentCache(prefs);
      final cache = UnifiedCache()..usePersistent(persistent);

      await persistent.writeRaw(
        'key',
        jsonEncode('disk'),
        const Duration(days: 1),
      );
      cache.set('key', 'memory', ttl: const Duration(days: 1));

      final value = await cache.getOrLoadPersistent<String>(
        key: 'key',
        loader: () async => 'network',
        ttl: const Duration(days: 1),
        decoder: (_) => throw StateError('disk must not be read'),
        encoder: (value) => value,
      );

      expect(value, 'memory');
    });
  });

  group('PersistentCache eviction', () {
    test('removes the oldest entries first', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = PersistentCache(prefs, maxEntries: 2);

      await cache.writeRaw('old', '"old"', const Duration(days: 1));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.writeRaw('middle', '"middle"', const Duration(days: 1));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.writeRaw('new', '"new"', const Duration(days: 1));

      expect(cache.count, 2);
      expect(cache.readEntry('old'), isNull);
      expect(cache.readEntry('middle'), isNotNull);
      expect(cache.readEntry('new'), isNotNull);
    });

    test('drops expired entries during enforcement', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = PersistentCache(prefs, maxEntries: 2);

      await cache.writeRaw(
        'expired',
        '"expired"',
        const Duration(milliseconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await cache.writeRaw('a', '"a"', const Duration(days: 1));
      await cache.writeRaw('b', '"b"', const Duration(days: 1));

      expect(cache.count, 2);
      expect(cache.readEntry('expired'), isNull);
      expect(cache.readEntry('a'), isNotNull);
      expect(cache.readEntry('b'), isNotNull);
    });
  });
}
