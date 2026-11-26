import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/api/metadata/unified_metadata.dart';
import 'package:anishka/core/api/sources/unified_source.dart';
import 'package:anishka/core/models/shikimori_anime.dart';

void main() {
  group('ShikimoriAnime parsing', () {
    test('tolerates missing and wrongly typed fields', () {
      final anime = ShikimoriAnime.fromJson(const {});

      expect(anime.id, 0);
      expect(anime.displayTitle, '');
      expect(anime.year, isNull);
      expect(anime.image.original, isNull);
    });

    test('coerces numeric strings and numeric ids', () {
      final anime = ShikimoriAnime.fromJson({
        'id': '42',
        'name': 'ATTACK ON TITAN',
        'russian': 'Атака титанов',
        'kind': 'tv',
        'score': 8.5,
        'status': 'released',
        'episodes': '25',
        'episodes_aired': 25.0,
        'url': '/animes/42',
      });

      expect(anime.id, 42);
      expect(anime.displayTitle, 'атака титанов');
      expect(anime.episodes, 25);
      expect(anime.episodesAired, 25);
      expect(anime.score, '8.5');
      expect(anime.image.original, isNull);
    });

    test('ignores malformed image and date values', () {
      final anime = ShikimoriAnime.fromJson({
        'id': 1,
        'name': 'x',
        'image': 'not-a-map',
        'aired_on': 'not-a-date',
      });

      expect(anime.image.original, isNull);
      expect(anime.year, isNull);
    });

    test('falls back to released_on for the year', () {
      final anime = ShikimoriAnime.fromJson({
        'id': 1,
        'name': 'x',
        'released_on': '2013-04-01',
      });

      expect(anime.year, 2013);
    });

    test('replaces a missing Shikimori poster with a fallback', () {
      final anime = ShikimoriAnime.fromJson({
        'id': 61469,
        'name': 'steel ball run',
        'image': {
          'original': '/assets/globals/missing_original.jpg',
          'preview': '/assets/globals/missing_preview.jpg',
        },
      });
      expect(anime.posterUrl, isNull);

      final patched = anime.copyWith(
        image: const ShikimoriImage(
          original: 'https://cdn.example/poster.jpg',
          preview: 'https://cdn.example/poster.jpg',
        ),
      );

      expect(patched.posterUrl, 'https://cdn.example/poster.jpg');
      expect(patched.id, 61469);
      expect(patched.displayTitle, 'steel ball run');
    });
  });

  group('ShikimoriAnimeDetails parsing', () {
    test('tolerates empty payload', () {
      final details = ShikimoriAnimeDetails.fromJson(const {});

      expect(details.id, 0);
      expect(details.displayTitle, '');
      expect(details.genres, isEmpty);
      expect(details.studios, isEmpty);
      expect(details.videos, isEmpty);
      expect(details.screenshots, isEmpty);
      expect(details.english, isEmpty);
      expect(details.descriptionText, '');
    });

    test('drops malformed list entries instead of throwing', () {
      final details = ShikimoriAnimeDetails.fromJson({
        'id': 10,
        'name': 'test',
        'genres': [
          {'id': 1, 'name': 'Action', 'russian': 'Экшен'},
          'broken',
          {'id': '2', 'russian': 'Драма'},
        ],
        'studios': [
          {'id': 3, 'name': 'Studio'},
          null,
        ],
        'videos': [
          {'id': 4, 'url': 'https://example/trailer', 'kind': 'pv'},
          42,
        ],
        'english': ['Test', 7, null, '  '],
        'screenshots': [
          {'original': '/system/screenshots/a.jpg'},
          {'original': null},
          'broken',
        ],
      });

      expect(
        (details.genres ?? const []).map((g) => g.russian),
        ['экшен', 'драма'],
      );
      expect((details.studios ?? const []).single.name, 'studio');
      expect(
        (details.videos ?? const []).single.url,
        'https://example/trailer',
      );
      expect(details.english, ['Test', '7']);
      expect(details.screenshots, hasLength(1));
    });
  });

  group('UnifiedMetadata parsing', () {
    test('tolerates empty payload', () {
      final metadata = UnifiedMetadata.fromJson(const {});

      expect(metadata.id, 0);
      expect(metadata.shikimoriId, 0);
      expect(metadata.title, '');
      expect(metadata.genres, isEmpty);
      expect(metadata.screenshots, isEmpty);
      expect(metadata.score, isNull);
    });

    test('coerces numeric strings and comma decimals', () {
      final metadata = UnifiedMetadata.fromJson({
        'id': '5',
        'shikimoriId': '20',
        'title': 'Naruto',
        'score': '7,83',
        'year': '2002',
        'episodes': 220.0,
        'genres': ['Action', 7, null],
        'studios': 'not-a-list',
      });

      expect(metadata.id, 5);
      expect(metadata.shikimoriId, 20);
      expect(metadata.score, 7.83);
      expect(metadata.year, 2002);
      expect(metadata.episodes, 220);
      expect(metadata.genres, ['Action', '7']);
      expect(metadata.studios, isEmpty);
    });

    test('round-trips through json', () {
      const metadata = UnifiedMetadata(
        id: 1,
        shikimoriId: 2,
        title: 'Test',
        genres: ['action'],
        studios: ['studio'],
        screenshots: ['https://example/1.jpg'],
        score: 8.1,
        year: 2020,
      );

      final decoded = UnifiedMetadata.fromJson(metadata.toJson());

      expect(decoded.title, 'Test');
      expect(decoded.genres, ['action']);
      expect(decoded.studios, ['studio']);
      expect(decoded.screenshots, ['https://example/1.jpg']);
      expect(decoded.score, 8.1);
      expect(decoded.year, 2020);
    });
  });

  group('UnifiedSource parsing', () {
    test('tolerates empty payload', () {
      final source = UnifiedSource.fromJson(const {});

      expect(source.id, '');
      expect(source.providerId, '');
      expect(source.episodes, isEmpty);
      expect(source.episodeCount, 0);
      expect(source.hasDirectStreams, isFalse);
      expect(source.requiresResolution, isFalse);
    });

    test('drops malformed episodes and keeps valid ones', () {
      final source = UnifiedSource.fromJson({
        'id': 'src',
        'providerId': 'anilibria',
        'title': 'AniLibria',
        'episodeCount': '2',
        'episodes': [
          {
            'id': 'ep1',
            'ordinal': '1',
            'title': 'Series 1',
            'hls720': 'https://example/1.m3u8',
            'streamHeaders': {'Referer': 'https://example/', 'Bad': null},
          },
          'broken',
          {
            'id': 2,
            'ordinal': 2,
            'title': null,
            'resolverSource': 'kodik',
            'resolverId': 123,
          },
        ],
        'hasDirectStreams': 'true',
      });

      expect(source.episodeCount, 2);
      expect(source.episodes, hasLength(2));
      expect(source.episodes.first.ordinal, 1);
      expect(source.episodes.first.hlsForQuality('720'), 'https://example/1.m3u8');
      expect(source.episodes.first.streamHeaders, {
        'Referer': 'https://example/',
      });
      expect(source.episodes.last.id, '2');
      expect(source.episodes.last.canResolve, isTrue);
      expect(source.hasDirectStreams, isTrue);
    });

    test('round-trips through json', () {
      final source = UnifiedSource(
        id: 'src',
        providerId: 'yani',
        title: 'Yani',
        episodeCount: 1,
        hasDirectStreams: true,
        episodes: [
          UnifiedEpisode(
            id: 'e1',
            ordinal: 1,
            title: 'Episode 1',
            hls720: 'https://example/1.m3u8',
            streamHeaders: const {'Origin': 'https://example'},
          ),
        ],
      );

      final decoded = UnifiedSource.fromJson(source.toJson());

      expect(decoded.id, 'src');
      expect(decoded.providerId, 'yani');
      expect(decoded.episodes.single.hls720, 'https://example/1.m3u8');
      expect(decoded.episodes.single.streamHeaders, {
        'Origin': 'https://example',
      });
      expect(decoded.hasDirectStreams, isTrue);
    });
  });
}
