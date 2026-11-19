import 'package:anishka/core/models/shikimori_anime.dart';
import 'package:flutter_test/flutter_test.dart';

ShikimoriAnimeDetails details(Map<String, dynamic> overrides) {
  return ShikimoriAnimeDetails.fromJson({
    'id': 40748,
    'name': 'Jujutsu Kaisen',
    'russian': 'Магическая битва',
    ...overrides,
  });
}

void main() {
  group('shikimori metadata merge', () {
    test('deduplicates studios case-insensitively', () {
      final anime = details({
        'studios': [
          {'id': 1, 'name': 'MAPPA'},
        ],
      }).copyWith(
        metadataStudios: const ['MAPPA', 'Studio Ghibli'],
      );

      expect(anime.allStudios, ['mappa', 'Studio Ghibli']);
    });

    test('deduplicates shikimori genres case-insensitively', () {
      final anime = details({
        'genres': [
          {'id': 1, 'name': 'Action', 'russian': 'ЭКШЕН'},
          {'id': 2, 'name': 'action', 'russian': 'экшен'},
          {'id': 3, 'name': 'Fantasy', 'russian': 'фэнтези'},
        ],
      });

      expect(anime.allGenres, ['экшен', 'фэнтези']);
    });

    test('falls back to metadata genres when shikimori has none', () {
      final anime = details({
        'genres': <Map<String, dynamic>>[],
      }).copyWith(
        metadataGenres: const ['Action', 'action', 'Supernatural'],
      );

      expect(anime.allGenres, ['Action', 'Supernatural']);
    });
  });
}
