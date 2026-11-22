import 'package:anishka/core/api/metadata/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('anilist media', () {
    test('parses titles, score, studios and cleans the description', () {
      final media = AniListMedia.fromJson({
        'id': 113415,
        'title': {
          'romaji': 'Jujutsu Kaisen',
          'english': 'JUJUTSU KAISEN',
          'native': '呪術廻戦',
        },
        'description': 'A boy fights...<br>\n<br>\nHardship &amp; regret.<br><br><br>More.',
        'averageScore': 84,
        'seasonYear': 2020,
        'episodes': 24,
        'duration': 24,
        'status': 'FINISHED',
        'format': 'TV',
        'genres': ['Action', 'Supernatural'],
        'studios': {
          'nodes': [
            {'name': 'MAPPA'},
            {'name': '  '},
          ],
        },
        'coverImage': {
          'extraLarge': 'https://img.example/cover.jpg',
          'large': 'https://img.example/large.jpg',
        },
        'bannerImage': 'https://img.example/banner.jpg',
        'trailer': {'id': 'RIyb52EMx8c', 'site': 'youtube'},
      });

      expect(media.id, 113415);
      expect(media.romaji, 'Jujutsu Kaisen');
      expect(media.displayEnglish, 'JUJUTSU KAISEN');
      expect(
        media.description,
        'a boy fights...\n\nhardship & regret.\n\nmore.',
      );
      expect(media.score, 8.4);
      expect(media.year, 2020);
      expect(media.episodes, 24);
      expect(media.duration, 24);
      expect(media.format, 'TV');
      expect(media.genres, ['Action', 'Supernatural']);
      expect(media.studios, ['MAPPA']);
      expect(media.posterUrl, 'https://img.example/cover.jpg');
      expect(media.bannerUrl, 'https://img.example/banner.jpg');
      expect(media.trailerUrl, 'https://www.youtube.com/watch?v=RIyb52EMx8c');
      expect(
        media.trailerThumbnail,
        'https://img.youtube.com/vi/RIyb52EMx8c/hqdefault.jpg',
      );
      expect(media.trailerSite, 'youtube');
    });

    test('maps dailymotion trailers and tolerates missing fields', () {
      final media = AniListMedia.fromJson({
        'id': 1,
        'title': <String, dynamic>{},
        'trailer': {'id': 'x7tgad0', 'site': 'Dailymotion'},
      });

      expect(media.trailerUrl, 'https://www.dailymotion.com/video/x7tgad0');
      expect(media.trailerThumbnail, isNull);
      expect(media.score, isNull);
      expect(media.displayEnglish, isNull);
      expect(media.description, isNull);
      expect(media.studios, isEmpty);
    });
  });

  group('kitsu media', () {
    test('parses titles, rating, dates and images', () {
      final media = KitsuMedia.fromJson({
        'id': '41370',
        'attributes': {
          'canonicalTitle': 'Jujutsu Kaisen',
          'titles': {
            'en': 'JUJUTSU KAISEN',
            'en_us': 'Jujutsu Kaisen',
            'ja_jp': '呪術廻戦',
          },
          'synopsis': 'A boy fights...',
          'averageRating': '85.9',
          'startDate': '2020-10-03',
          'episodeCount': 24,
          'episodeLength': 24,
          'posterImage': {'large': 'https://media.kitsu.io/poster.jpg'},
          'coverImage': {'original': 'https://media.kitsu.io/cover.jpg'},
          'youtubeVideoId': 'RIyb52EMx8c',
          'ageRating': 'R',
          'status': 'finished',
        },
      });

      expect(media.id, '41370');
      expect(media.canonicalTitle, 'Jujutsu Kaisen');
      expect(media.englishTitle, 'JUJUTSU KAISEN');
      expect(media.japaneseTitle, '呪術廻戦');
      expect(media.score, closeTo(8.59, 0.001));
      expect(media.year, 2020);
      expect(media.episodes, 24);
      expect(media.episodeLength, 24);
      expect(media.posterUrl, 'https://media.kitsu.io/poster.jpg');
      expect(media.coverUrl, 'https://media.kitsu.io/cover.jpg');
      expect(media.youtubeVideoId, 'RIyb52EMx8c');
      expect(media.ageRating, 'R');
      expect(media.status, 'finished');
    });

    test('falls back to en_us titles, original posters and no rating', () {
      final media = KitsuMedia.fromJson({
        'id': 7,
        'attributes': {
          'titles': {'en_us': 'Fallback Title'},
          'posterImage': {'original': 'https://media.kitsu.io/original.jpg'},
          'startDate': '1999',
        },
      });

      expect(media.englishTitle, 'Fallback Title');
      expect(media.posterUrl, 'https://media.kitsu.io/original.jpg');
      expect(media.year, 1999);
      expect(media.score, isNull);
      expect(media.episodes, isNull);
    });
  });
}
