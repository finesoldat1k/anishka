import 'package:anishka/core/models/anime_release.dart';
import 'package:anishka/core/storage/library_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnimeRelease release(int id, {String name = 'тестовое аниме'}) {
  return AnimeRelease.fromSnapshot({
    'id': id,
    'alias': 'release-$id',
    'name': name,
    'poster': '/storage/$id.jpg',
    'is_ongoing': false,
    'episodes_total': 12,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores statuses, favorites and progress', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryStore(prefs);
    final anime = release(1);

    expect(store.all, isEmpty);
    expect(store.isFavorite(anime.id), isFalse);
    expect(store.statusOf(anime.id), isNull);

    store.setStatus(anime, CollectionStatus.watching);
    expect(store.statusOf(anime.id), CollectionStatus.watching);
    expect(store.countStatus(CollectionStatus.watching), 1);
    expect(store.byStatus(CollectionStatus.watching).single.anime.id, 1);

    store.toggleFavorite(anime);
    expect(store.isFavorite(anime.id), isTrue);
    expect(store.countFavorites(), 1);
    expect(store.all, hasLength(1));

    store.saveProgress(releaseId: anime.id, episode: 4, voice: 'anilibria');
    expect(store.lastEpisodeFor(anime.id), 4);
    expect(store.voiceFor(anime.id), 'anilibria');
    expect(store.progressFor(anime.id)?.episode, 4);

    store.setStatus(anime, null);
    expect(store.statusOf(anime.id), isNull);
    expect(store.isFavorite(anime.id), isTrue);
    expect(store.all, hasLength(1));

    store.toggleFavorite(anime);
    expect(store.all, isEmpty);
  });

  test(
    'moves entries between collection statuses without duplicates',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryStore(prefs);
      final anime = release(2);

      store.setStatus(anime, CollectionStatus.planned);
      store.setStatus(anime, CollectionStatus.watching);
      store.setStatus(anime, CollectionStatus.completed);

      expect(store.all, hasLength(1));
      expect(store.countStatus(CollectionStatus.planned), 0);
      expect(store.countStatus(CollectionStatus.watching), 0);
      expect(store.countStatus(CollectionStatus.completed), 1);
      expect(store.statusOf(anime.id), CollectionStatus.completed);
    },
  );

  test('restores library and progress from shared preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryStore(prefs);
    final anime = release(3, name: 'сохранённое аниме');

    store.setStatus(anime, CollectionStatus.planned);
    store.toggleFavorite(anime);
    store.saveProgress(releaseId: anime.id, episode: 2, voice: 'anilibria');

    final restored = LibraryStore(prefs);
    final entry = restored.entryFor(anime.id);

    expect(entry, isNotNull);
    expect(entry!.anime.displayTitle, 'сохранённое аниме');
    expect(entry.status, CollectionStatus.planned);
    expect(entry.favorite, isTrue);
    expect(restored.lastEpisodeFor(anime.id), 2);
  });

  test('notifies listeners only when state changes', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryStore(prefs);
    final anime = release(4);
    var notifications = 0;

    store.addListener(() => notifications++);
    store.setStatus(anime, CollectionStatus.watching);
    expect(notifications, 1);

    store.setStatus(anime, CollectionStatus.watching);
    expect(notifications, 2);

    store.saveProgress(releaseId: anime.id, episode: 1, voice: 'anilibria');
    expect(notifications, 3);

    store.saveProgress(releaseId: anime.id, episode: 1, voice: 'anilibria');
    expect(notifications, 3);
  });

  test(
    'temporary snapshot and playable release share one library entry',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LibraryStore(prefs);
      final temporary = AnimeRelease.fromSnapshot({
        'id': -7,
        'shikimori_id': 7,
        'alias': 'temporary',
        'name': 'временный снапшот',
        'is_ongoing': true,
        'episodes_total': 12,
      });
      final playable = AnimeRelease.fromSnapshot({
        'id': 7,
        'shikimori_id': 7,
        'alias': 'release-7',
        'name': 'настоящий релиз',
        'is_ongoing': true,
        'episodes_total': 12,
      });

      store.toggleFavorite(temporary);
      expect(store.isFavorite(7), isTrue);
      expect(store.entryFor(-7), isNull);
      expect(store.countFavorites(), 1);

      store.syncSnapshot(playable);
      expect(store.entryFor(7)!.anime.id, 7);
      expect(store.entryFor(7)!.anime.displayTitle, 'настоящий релиз');

      store.setStatus(playable, CollectionStatus.watching);
      expect(store.countFavorites(), 1);
      expect(store.statusOf(7), CollectionStatus.watching);

      store.toggleFavorite(playable);
      expect(store.isFavorite(7), isFalse);
      expect(store.statusOf(7), CollectionStatus.watching);
    },
  );

  test('loads legacy negative-id entries under the canonical id', () async {
    SharedPreferences.setMockInitialValues({
      'anishka.library.v1':
          '[{"anime":{"id":-9,"shikimori_id":9,"alias":"legacy",'
          '"name":"старая запись","is_ongoing":false,"episodes_total":12},'
          '"status":"planned","favorite":true,'
          '"updated_at":"2026-01-01T00:00:00.000"},'
          '{"anime":{"id":9,"shikimori_id":9,"alias":"fresh",'
          '"name":"новая запись","is_ongoing":false,"episodes_total":12},'
          '"status":null,"favorite":false,'
          '"updated_at":"2026-02-01T00:00:00.000"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryStore(prefs);

    expect(store.isFavorite(9), isTrue);
    expect(store.statusOf(9), CollectionStatus.planned);
    expect(store.entryFor(-9), isNull);
    expect(store.all.length, 1);
  });

  test('libraryId prefers shikimoriId over temporary negative id', () {
    final temporary = AnimeRelease.fromSnapshot({
      'id': -3,
      'shikimori_id': 3,
      'alias': 'x',
      'name': 'x',
    });
    final playable = release(3);

    expect(temporary.libraryId, 3);
    expect(playable.libraryId, 3);
    expect(release(-2).libraryId, -2);
  });
}
