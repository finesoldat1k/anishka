import 'package:anishka/core/models/anime_episode.dart';
import 'package:anishka/core/models/anime_release.dart';
import 'package:anishka/core/models/voiceover.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> episodeJson({
  required int id,
  required int ordinal,
  int sortOrder = 0,
}) {
  return {
    'id': 'episode-$id',
    'ordinal': ordinal,
    'name': 'НАЗВАНИЕ СЕРИИ',
    'hls_480': '/storage/480/$id.m3u8',
    'hls_720': '/storage/720/$id.m3u8',
    'hls_1080': '/storage/1080/$id.m3u8',
    'duration': 1450,
    'preview': {'preview': '/storage/preview/$id.jpg'},
    'opening': {'start': 30, 'stop': 120},
    'ending': {'start': 1320, 'stop': 1420},
    'sort_order': sortOrder,
  };
}

Map<String, dynamic> releaseJson() {
  return {
    'id': 42,
    'alias': 'test-release',
    'name': {
      'main': 'ТЕСТОВЫЙ РЕЛИЗ',
      'english': 'TEST RELEASE',
      'alternative': 'АЛЬТЕРНАТИВНОЕ',
    },
    'description': 'ОПИСАНИЕ\r\nРЕЛИЗА',
    'year': 2025,
    'type': {'description': 'TV'},
    'season': {'description': 'ВЕСНА'},
    'age_rating': {'label': '16+'},
    'shikimori': {'rating': 8.4},
    'rating': {'average': 4.5},
    'poster': {
      'optimized': {
        'preview': '/storage/poster.jpg',
        'thumbnail': '/storage/poster-thumb.jpg',
      },
    },
    'background_covers': [
      {
        'optimized': {'preview': '/storage/background.jpg'},
      },
    ],
    'is_ongoing': true,
    'is_in_production': false,
    'episodes_total': 2,
    'genres': [
      {'name': 'ЭКШЕН'},
      {'name': 'ФЭНТЕЗИ'},
    ],
    'members': [
      {
        'nickname': 'ИВАН ОЗВУЧКА',
        'role': {'value': 'voicing', 'description': 'озвучка'},
        'user': {
          'avatar': {'preview': '/storage/avatar.jpg'},
        },
      },
      {
        'nickname': 'РЕЖИССЁР',
        'role': {'value': 'director', 'description': 'режиссёр'},
        'user': {},
      },
    ],
    'episodes': [
      episodeJson(id: 2, ordinal: 2, sortOrder: 2),
      episodeJson(id: 1, ordinal: 1, sortOrder: 1),
    ],
    'publish_day': {'description': 'ПЯТНИЦА'},
    'is_blocked_by_geo': false,
    'is_blocked_by_copyrights': false,
    'fresh_at': '2025-04-01T10:00:00.000Z',
  };
}

void main() {
  group('anime episode', () {
    test('parses streams, duration and skip markers', () {
      final episode = AnimeEpisode.fromJson(episodeJson(id: 1, ordinal: 1));

      expect(episode.ordinal, 1);
      expect(episode.displayName, 'название серии');
      expect(episode.hasStream, isTrue);
      expect(episode.streamUrl, contains('/1080/'));
      expect(episode.hlsForQuality('720'), contains('/720/'));
      expect(episode.hlsForQuality('1080'), contains('/1080/'));
      expect(episode.duration, const Duration(seconds: 1450));
      expect(episode.openingStartDuration, const Duration(seconds: 30));
      expect(episode.openingStopDuration, const Duration(seconds: 120));
      expect(episode.endingStartDuration, const Duration(seconds: 1320));
      expect(episode.endingStopDuration, const Duration(seconds: 1420));
      expect(episode.previewUrl, startsWith('https://anilibria.top/'));
    });

    test('falls back to a numbered episode name and detects no stream', () {
      final episode = AnimeEpisode.fromJson({
        'id': 'x',
        'ordinal': 3,
        'name': '   ',
        'hls_480': null,
        'hls_720': null,
        'hls_1080': null,
      });

      expect(episode.displayName, 'серия 3');
      expect(episode.hasStream, isFalse);
      expect(episode.duration, isNull);
    });
  });

  group('anime release', () {
    test('parses metadata, lowercases display text and sorts episodes', () {
      final release = AnimeRelease.fromJson(releaseJson());

      expect(release.id, 42);
      expect(release.displayTitle, 'тестовый релиз');
      expect(release.displayEnglish, 'test release');
      expect(release.displayDescription, 'описание\nрелиза');
      expect(release.displayGenres, ['экшен', 'фэнтези']);
      expect(release.episodes.map((episode) => episode.ordinal), [1, 2]);
      expect(release.episodeByOrdinal(2)?.id, 'episode-2');
      expect(release.score, 8.4);
      expect(release.statusLabel, 'онгоинг');
      expect(release.isBlocked, isFalse);
      expect(release.voiceActors.single.displayName, 'иван озвучка');
      expect(release.voiceCastLabel, 'иван озвучка');
      expect(release.primaryMeta, contains('2025'));
      expect(release.posterThumbUrl, contains('poster-thumb.jpg'));
      expect(release.backgroundUrl, contains('background.jpg'));
    });

    test('survives a snapshot round-trip for local storage', () {
      final release = AnimeRelease.fromJson(releaseJson());
      final snapshot = AnimeRelease.fromSnapshot(release.toSnapshotJson());

      expect(snapshot.id, release.id);
      expect(snapshot.displayTitle, release.displayTitle);
      expect(snapshot.posterUrl, release.posterUrl);
      expect(snapshot.genres, release.genres);
      expect(snapshot.isOngoing, isTrue);
      expect(snapshot.score, release.score);
      expect(snapshot.freshAt, release.freshAt);
    });
  });

  group('voiceovers', () {
    test('exposes a single anilibria track with a lowercase cast', () {
      final release = AnimeRelease.fromJson(releaseJson());
      final voices = voiceoversFor(release);

      expect(voices, hasLength(1));
      expect(voices.single.id, defaultVoiceoverId);
      expect(voices.single.title, 'русская озвучка');
      expect(voices.single.subtitle, 'anilibria · иван озвучка');
      expect(voiceoverById(release, 'unknown').id, defaultVoiceoverId);
    });
  });
}
