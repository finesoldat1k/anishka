import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/api/sources/anilibme.dart';
import 'package:anishka/core/api/sources/anilibria.dart';
import 'package:anishka/core/api/sources/kodik.dart';

void main() {
  group('kodik sources', () {
    test('reads one embed per season and exposes every translation', () async {
      final adapter = _KodikAdapter();
      final kodik = Kodik(dio: _dio(adapter));

      final found = await kodik.findByShikimoriId(
        40748,
        nameHint: 'Тест',
      );

      expect(found, hasLength(3));
      expect(
        found.map((source) => source.title),
        ['Студия А', 'Студия Б', 'Студия В'],
      );
      expect(
        found.map((source) => source.episodes.length),
        [2, 2, 1],
      );
      expect(adapter.embedFetches, 1);
      expect(
        found.first.episodes.last.resolverId,
        contains('season=1&episode=2'),
      );
      expect(found.first.id, startsWith('kodik::serial-1::'));
    });

    test('falls back to the search payload when the embed is unavailable',
        () async {
      final adapter = _KodikAdapter(embedBody: '');
      final kodik = Kodik(dio: _dio(adapter));

      final found = await kodik.findByShikimoriId(40748);

      expect(found, hasLength(3));
      expect(found.first.episodes, hasLength(3));
      expect(found.first.episodes.last.ordinal, 3);
      expect(found.last.episodes, hasLength(1));
      expect(
        found.first.episodes.last.resolverId,
        contains('episode=3'),
      );
    });

    test('getSource looks the material up by its Kodik id', () async {
      final adapter = _KodikAdapter();
      final kodik = Kodik(dio: _dio(adapter));
      final found = await kodik.findByShikimoriId(40748);
      adapter.filters.clear();

      final full = await kodik.getSource(found.first.id);

      expect(full, isNotNull);
      expect(full!.episodes, hasLength(2));
      expect(adapter.filters.single['id'], 'serial-1');
      expect(adapter.filters.single.containsKey('kodik_id'), isFalse);
    });
  });

  group('anilibria sources', () {
    test('accepts a namespaced source id', () async {
      final adapter = _AnilibriaAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://anilibria.top/api/v1'))
        ..httpClientAdapter = adapter;

      final source = await AniLibria(dio: dio).getSource('anilibria:8789');

      expect(source, isNotNull);
      expect(source!.episodes, hasLength(2));
      expect(source.episodes.first.hls720, isNotEmpty);
    });

    test('still accepts a bare release id', () async {
      final adapter = _AnilibriaAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://anilibria.top/api/v1'))
        ..httpClientAdapter = adapter;

      final source = await AniLibria(dio: dio).getSource('8789');

      expect(source, isNotNull);
      expect(source!.episodes, hasLength(2));
    });
  });

  group('anilibme sources', () {
    test('uses the /api endpoint and sends the required headers', () async {
      final adapter = _AnilibmeAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.cdnlibs.org/api'))
        ..httpClientAdapter = adapter;

      final found = await AnilibMe(dio: dio).search('Тест');

      expect(found, hasLength(1));
      expect(found.single.title, 'Тест');
      expect(adapter.paths.single, '/api/anime');
      expect(adapter.origins.single, 'https://animelib.org');
      expect(adapter.referers.single, 'https://animelib.org/');
    });
  });
}

Dio _dio(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://kodik-api.com'))
    ..httpClientAdapter = adapter;
}

class _KodikAdapter implements HttpClientAdapter {
  _KodikAdapter({this.embedBody = _defaultEmbed});

  final String embedBody;
  int embedFetches = 0;
  final List<Map<String, dynamic>> filters = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host == 'kodikplayer.com') {
      embedFetches++;
      return _html(embedBody);
    }
    if (options.uri.host == 'kodik-api.com') {
      final data = options.data;
      if (data is Map) {
        filters.add(data.map((key, value) => MapEntry('$key', value)));
      }
      return _json({
        'results': [
          {
            'id': 'serial-1',
            'type': 'anime-serial',
            'link': '//kodikplayer.com/serial/1/hash1/720p',
            'title': 'Тест [ТВ-1]',
            'year': 2020,
            'last_season': 1,
            'last_episode': 3,
            'episodes_count': 3,
            'translation': {'id': 10, 'title': 'Студия А'},
          },
          {
            'id': 'serial-2',
            'type': 'anime-serial',
            'link': '//kodikplayer.com/serial/2/hash2/720p',
            'title': 'Тест [ТВ-1]',
            'year': 2020,
            'last_season': 1,
            'last_episode': 3,
            'episodes_count': 3,
            'translation': {'id': 20, 'title': 'Студия Б'},
          },
          {
            'id': 'serial-3',
            'type': 'anime-serial',
            'link': '//kodikplayer.com/serial/3/hash3/720p',
            'title': 'Тест [ТВ-1]',
            'year': 2020,
            'last_season': 1,
            'last_episode': 1,
            'episodes_count': 1,
            'translation': {'id': 30, 'title': 'Студия В'},
          },
        ],
      });
    }
    return _empty();
  }

  @override
  void close({bool force = false}) {}
}

class _AnilibriaAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/anime/releases/8789')) {
      return _json({
        'id': 8789,
        'name': {'main': 'Тест'},
        'shikimori': {'id': 40748},
        'episodes': [
          {
            'id': 'e1',
            'ordinal': 1,
            'name': 'серия 1',
            'hls_720': 'https://example.com/1.m3u8',
          },
          {
            'id': 'e2',
            'ordinal': 2,
            'name': 'серия 2',
            'hls_720': 'https://example.com/2.m3u8',
          },
        ],
      });
    }
    return _empty();
  }

  @override
  void close({bool force = false}) {}
}

class _AnilibmeAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  final List<String?> origins = [];
  final List<String?> referers = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    origins.add(options.headers['Origin']?.toString());
    referers.add(options.headers['Referer']?.toString());
    if (options.uri.path == '/api/anime') {
      return _json({
        'data': [
          {
            'id': 1,
            'name': 'Test',
            'rus_name': 'Тест',
            'slug_url': '1--test-anime',
            'cover': {'default': 'https://example.com/cover.jpg'},
          },
        ],
      });
    }
    return _empty();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object value) {
  return ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _html(String value) {
  return ResponseBody.fromString(
    value,
    200,
    headers: {
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    },
  );
}

ResponseBody _empty() {
  return ResponseBody.fromString('', 404);
}

const _defaultEmbed = '''
<div class="serial-seasons-box">
  <select><option value="1" selected="selected">1 сезон</option></select>
</div>
<div class="serial-translations-box">
  <select>
    <option value="10" data-media-id="1" data-media-hash="hash1"
      data-title="Студия А" data-episode-count="2">Студия А (2 эп.)</option>
    <option value="20" data-media-id="2" data-media-hash="hash2"
      data-title="Студия Б" data-episode-count="2">Студия Б (2 эп.)</option>
    <option value="30" data-media-id="3" data-media-hash="hash3"
      data-title="Студия В" data-episode-count="1">Студия В (1 эп.)</option>
  </select>
</div>
<div class="series-options">
  <div class="season-1">
    <select>
      <option value="1">1 серия</option>
      <option value="2">2 серия</option>
    </select>
  </div>
</div>
<script>
  // The page's own script mentions promo-error; it must not hide the source.
  document.body.append('<div class="promo-error"></div>');
</script>
''';
