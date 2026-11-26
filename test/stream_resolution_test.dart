import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/api/sources/embed/aksor_resolver.dart';
import 'package:anishka/core/api/sources/embed/aniboom_resolver.dart';
import 'package:anishka/core/api/sources/embed/cdnvideohub_resolver.dart';
import 'package:anishka/core/api/sources/embed/embed_http.dart';
import 'package:anishka/core/api/sources/embed/kodik_resolver.dart';
import 'package:anishka/core/api/sources/embed/sibnet_resolver.dart';
import 'package:anishka/core/api/sources/hdrezka.dart';
import 'package:anishka/core/api/sources/resolved_stream.dart';
import 'package:anishka/core/api/sources/sameband.dart';

void main() {
  group('ResolvedStream', () {
    test('round-trips through json', () {
      const stream = ResolvedStream(
        url: 'https://cdn.example/720.m3u8',
        headers: {'Referer': 'https://example/'},
        kind: StreamKind.hls,
        quality: '720',
      );

      final decoded = ResolvedStream.fromJson(stream.toJson());

      expect(decoded.url, stream.url);
      expect(decoded.headers, stream.headers);
      expect(decoded.kind, StreamKind.hls);
      expect(decoded.quality, '720');
      expect(decoded.isPlayable, isTrue);
    });

    test('detects stream kind from url', () {
      expect(StreamKind.fromUrl('https://x/a.m3u8?t=1'), StreamKind.hls);
      expect(StreamKind.fromUrl('https://x/a.mpd'), StreamKind.dash);
      expect(StreamKind.fromUrl('https://x/a.mp4'), StreamKind.mp4);
      expect(StreamKind.fromUrl('https://x/live'), StreamKind.auto);
    });

    test('json omits empty headers', () {
      const stream = ResolvedStream(url: 'https://x/a.mp4');
      expect(stream.toJson().containsKey('headers'), isFalse);
    });

    test('round-trips quality variants', () {
      const stream = ResolvedStream(
        url: 'https://cdn.example/1080.m3u8',
        quality: '1080',
        variants: {
          '1080': ResolvedStream(
            url: 'https://cdn.example/1080.m3u8',
            quality: '1080',
          ),
          '720': ResolvedStream(
            url: 'https://cdn.example/720.m3u8',
            quality: '720',
          ),
        },
      );

      final decoded = ResolvedStream.fromJson(stream.toJson());

      expect(decoded.variants.keys, containsAll(['1080', '720']));
      expect(decoded.variants['720']!.url, 'https://cdn.example/720.m3u8');
      expect(decoded.variants['720']!.variants, isEmpty);
    });
  });

  group('Kodik URL decoding', () {
    test('decodes rot18 + base64', () {
      // ROT-18 of the base64 of https://cdn.example.com/720.mp4.
      const encoded = 'iPZ0kPU6Tg9rHO4cHFppjFJaHA5rj20dVhQeTu1eVI==';
      expect(decodeKodikUrl(encoded), 'https://cdn.example.com/720.mp4');
    });

    test('keeps plain m3u8 urls', () {
      expect(
        decodeKodikUrl('//cdn.example.com/live.m3u8'),
        'https://cdn.example.com/live.m3u8',
      );
    });

    test('returns null for garbage', () {
      expect(decodeKodikUrl('not-base64-at-all'), isNull);
    });

    test('parses api links and fixes the 720 bucket', () {
      final links = <dynamic, dynamic>{
        '720': [
          {'src': 'iPZ0kPU6Tg9rHO4cHFppjFJaHA5rj20dVLoeTu1eVLw3UrI='},
        ],
        '480': [
          {'src': '//cdn.example.com/480.m3u8'},
        ],
      };

      final streams = KodikResolver.parseLinks(links);

      expect(streams.keys, containsAll(['720', '480']));
      expect(streams['720']!.url, 'https://cdn.example.com/720.mp4:720');
      expect(streams['480']!.kind, StreamKind.hls);
      expect(streams['720']!.headers['Referer'], 'https://kodik.info/');
    });
  });

  group('quality selection', () {
    test('auto picks the highest quality', () {
      expect(pickQuality(['360', '1080', '720']), '1080');
    });

    test('requested picks the closest quality', () {
      expect(
        pickQuality(['360', '480', '720', '1080'], requested: '720'),
        '720',
      );
      expect(pickQuality(['360', '480', '1080'], requested: '720'), '480');
    });
  });

  group('HDRezka stream parsing', () {
    test('parses qualities and prefers hls', () {
      const raw =
          '[1080p]https://cdn.example/1080.mp4 or https://cdn.example/1080.m3u8,'
          '[720p]https://cdn.example/720.m3u8,'
          '[480p]https://cdn.example/480.mp4';

      final streams = HDRezka.parseStreams(raw);

      expect(streams.keys, containsAll(['1080', '720', '480']));
      expect(streams['1080']!.url, 'https://cdn.example/1080.m3u8');
      expect(streams['1080']!.kind, StreamKind.hls);
      expect(streams['480']!.kind, StreamKind.mp4);
      expect(streams['720']!.headers['Referer'], 'https://hdrezka-home.tv/');
    });

    test('ignores empty input', () {
      expect(HDRezka.parseStreams(''), isEmpty);
    });
  });

  group('SameBand playlist parsing', () {
    test('maps playerjs qualities to episodes', () {
      const body = '''
[
  {
    "title": "Серия 1",
    "file": "[480p]https://cdn.example/1/480.m3u8,[720p]https://cdn.example/1/720.m3u8,[1080p]https://cdn.example/1/1080.m3u8"
  },
  {
    "title": "Серия 2",
    "file": "[720p]https://cdn.example/2/720.m3u8"
  }
]
''';

      final episodes = SameBand.parsePlaylist(body);

      expect(episodes, hasLength(2));
      expect(episodes.first.ordinal, 1);
      expect(episodes.first.hls480, 'https://cdn.example/1/480.m3u8');
      expect(episodes.first.hls720, 'https://cdn.example/1/720.m3u8');
      expect(episodes.first.hls1080, 'https://cdn.example/1/1080.m3u8');
      expect(episodes.last.hls720, 'https://cdn.example/2/720.m3u8');
      expect(episodes.last.hls480, isNull);
    });

    test('ignores malformed playlists', () {
      expect(SameBand.parsePlaylist('not json'), isEmpty);
      expect(SameBand.parsePlaylist('{}'), isEmpty);
    });
  });

  group('Aniboom parameters', () {
    test('parses escaped json', () {
      const raw =
          '{"hls":"{\\"src\\":\\"https://cdn.example/master.m3u8\\"}",'
          '"qualityVideo":"1080"}';

      final params = AniboomResolver.parseParameters(raw);

      expect(params, isNotNull);
      expect(params!['qualityVideo'], '1080');
      expect(params['hls'], contains('master.m3u8'));
    });

    test('returns null for empty payload', () {
      expect(AniboomResolver.parseParameters(''), isNull);
      expect(AniboomResolver.parseParameters('nope'), isNull);
    });
  });

  group('CDNVideoHub parsing', () {
    test('splits cdn-iframe path parts', () {
      final parts = CdnVideoHubResolver.parsePathParts(
        'https://animego.me/cdn-iframe/1234/Studio%20X/2/5?foo=1',
      );

      expect(parts, isNotNull);
      expect(parts!.id, '1234');
      expect(parts.dubber, 'Studio X');
      expect(parts.season, '2');
      expect(parts.episode, '5');
    });

    test('reads video-player attributes', () {
      const html =
          '<video-player data-title-id="123" data-publisher-id="pub" '
          'data-aggregator="aggr"></video-player>';

      final params = CdnVideoHubResolver.parsePlayerParams(html);

      expect(params, isNotNull);
      expect(params!.titleId, '123');
      expect(params.publisherId, 'pub');
      expect(params.aggregator, 'aggr');
    });

    test('rejects pages without a player', () {
      expect(CdnVideoHubResolver.parsePlayerParams('<div></div>'), isNull);
      expect(
        CdnVideoHubResolver.parsePathParts('https://animego.me/anime/1'),
        isNull,
      );
    });
  });

  group('Sibnet parsing', () {
    test('extracts the mp4 path', () {
      const html = '... file: "/v/abc123.mp4" ...';
      expect(SibnetResolver.parseVideoPath(html), '/v/abc123.mp4');
    });

    test('returns null without a video', () {
      expect(SibnetResolver.parseVideoPath('<html></html>'), isNull);
    });
  });

  group('Aksor parsing', () {
    test('extracts numeric video id', () {
      expect(
        AksorResolver.parseVideoId('https://player.aksor.tv/video/98765?x=1'),
        '98765',
      );
      expect(AksorResolver.parseVideoId('https://player.aksor.tv/'), isNull);
    });
  });
}
