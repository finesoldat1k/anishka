import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anishka/core/models/anime_release.dart';
import 'package:anishka/core/models/anime_source.dart';
import 'package:anishka/core/models/shikimori_anime.dart';
import 'package:anishka/core/storage/library_store.dart';
import 'package:anishka/core/theme/app_theme.dart';
import 'package:anishka/features/details/widgets/details_hero.dart';

void main() {
  testWidgets('bookmark menu opens and saves the selected status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final library = LibraryStore(prefs);
    final details = ShikimoriAnimeDetails(
      id: 42,
      name: 'test anime',
      russian: 'тестовое аниме',
      kind: 'tv',
      score: '8.0',
      status: 'ongoing',
      episodes: 12,
      episodesAired: 5,
      image: const ShikimoriImage(),
      url: '/animes/42',
    );
    final anime = AnimeWithSources(shikimoriAnime: details, sources: const []);
    final snapshot = AnimeRelease.fromShikimoriDetails(details);

    await tester.pumpWidget(
      ChangeNotifierProvider<LibraryStore>.value(
        value: library,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: DetailsHero(
              anime: anime,
              librarySnapshot: snapshot,
              compact: false,
              onPlay: () {},
              onToggleFavorite: () => library.toggleFavorite(snapshot),
              onSelectStatus: (status) => library.setStatus(snapshot, status),
              onRemoveStatus: () => library.setStatus(snapshot, null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('закладка'));
    await tester.pumpAndSettle();
    expect(find.text('в планах'), findsOneWidget);

    await tester.tap(find.text('в планах'));
    await tester.pumpAndSettle();

    expect(library.statusOf(snapshot.libraryId), CollectionStatus.planned);
    expect(find.text('в планах'), findsOneWidget);
  });

  testWidgets('favourite button stays solid and toggles the label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final library = LibraryStore(prefs);
    final details = ShikimoriAnimeDetails(
      id: 7,
      name: 'test anime',
      russian: 'тестовое аниме',
      kind: 'tv',
      score: '7.5',
      status: 'released',
      episodes: 12,
      episodesAired: 12,
      image: const ShikimoriImage(),
      url: '/animes/7',
    );
    final anime = AnimeWithSources(shikimoriAnime: details, sources: const []);
    final snapshot = AnimeRelease.fromShikimoriDetails(details);

    await tester.pumpWidget(
      ChangeNotifierProvider<LibraryStore>.value(
        value: library,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: DetailsHero(
              anime: anime,
              librarySnapshot: snapshot,
              compact: false,
              onPlay: () {},
              onToggleFavorite: () => library.toggleFavorite(snapshot),
              onSelectStatus: (status) => library.setStatus(snapshot, status),
              onRemoveStatus: () => library.setStatus(snapshot, null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('в избранное'));
    await tester.pumpAndSettle();

    expect(library.isFavorite(snapshot.libraryId), isTrue);
    expect(find.text('в избранном'), findsOneWidget);
  });
}
