import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anishka/core/api/service_registry.dart';
import 'package:anishka/core/cache/unified_cache.dart';
import 'package:anishka/core/models/anime_episode.dart';
import 'package:anishka/core/models/anime_release.dart';
import 'package:anishka/core/models/anime_source.dart';
import 'package:anishka/core/models/shikimori_anime.dart';
import 'package:anishka/core/models/voiceover.dart';
import 'package:anishka/core/repository/unified_repository.dart';
import 'package:anishka/core/services/app_services.dart';
import 'package:anishka/core/storage/library_store.dart';
import 'package:anishka/core/storage/playback_settings_store.dart';
import 'package:anishka/core/storage/search_store.dart';
import 'package:anishka/app.dart';
import 'package:anishka/core/theme/app_theme.dart';
import 'package:anishka/features/details/details_screen.dart';

void main() {
  testWidgets('full app updates the details hero after a favourite tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final library = LibraryStore(prefs);
    final search = SearchStore(prefs);
    final playback = PlaybackSettingsStore(prefs);
    final services = _FakeServices(prefs: prefs, result: _result());

    await tester.pumpWidget(
      AnishkaApp(
        services: services,
        library: library,
        search: search,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();

    final card = find.textContaining('тестовое');
    expect(card, findsWidgets);
    await tester.tap(card.first);
    await tester.pumpAndSettle();

    expect(find.text('в избранное'), findsOneWidget);
    await tester.tap(find.text('в избранное'));
    await tester.pumpAndSettle();

    expect(library.isFavorite(42), isTrue);
    expect(find.text('в избранном'), findsOneWidget);
  });

  testWidgets('details page reflects library changes without a reload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final library = LibraryStore(prefs);
    final search = SearchStore(prefs);
    final services = _FakeServices(prefs: prefs, result: _result());
    final repository = services.repository;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppServices>.value(value: services),
          Provider<UnifiedRepository>.value(value: repository),
          ChangeNotifierProvider<LibraryStore>.value(value: library),
          ChangeNotifierProvider<SearchStore>.value(value: search),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const DetailsScreen(shikimoriId: 42),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('в избранное'), findsOneWidget);
    await tester.tap(find.text('в избранное'));
    await tester.pumpAndSettle();

    expect(library.isFavorite(42), isTrue);
    expect(find.text('в избранном'), findsOneWidget);

    await tester.tap(find.text('закладка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('смотрю').last);
    await tester.pumpAndSettle();

    expect(library.statusOf(42), CollectionStatus.watching);
    expect(find.text('смотрю'), findsWidgets);
  });
}

class _FakeServices extends AppServices {
  _FakeServices({required super.prefs, required this.result});

  final AnimeWithSources result;

  @override
  UnifiedRepository get repository => _repository(result);
}

UnifiedRepository _repository(AnimeWithSources result) =>
    _FakeRepository(result);

class _FakeRepository extends UnifiedRepository {
  _FakeRepository(this.result)
    : super(
        registry: ApiServiceRegistry(
          metadata: MetadataProviderRegistry.create(
            providers: const [],
            enabledIds: const {},
          ),
          sources: SourceProviderRegistry.create(
            providers: const [],
            enabledIds: const {},
          ),
        ),
        cache: UnifiedCache(),
      );

  final AnimeWithSources result;

  @override
  AnimeWithSources? cachedAnimeWithSources(int shikimoriId) => result;

  @override
  Future<List<ShikimoriAnime>> getPopular({
    bool refresh = false,
    int limit = 50,
    int page = 1,
    String order = 'popularity',
    String? status,
    String? kind,
  }) async {
    return [
      ShikimoriAnime(
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
      ),
    ];
  }

  @override
  Future<AnimeWithSources> getAnimeWithSources(
    int shikimoriId, {
    bool refresh = false,
    String? titleHint,
    void Function(AnimeWithSources partial)? onPartial,
  }) async {
    return result;
  }
}

AnimeWithSources _result() {
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
  final release = AnimeRelease(
    id: 42,
    alias: '',
    name: details.displayTitle,
    englishName: details.name,
    description: null,
    year: details.year,
    type: details.kind,
    season: null,
    ageRating: details.rating,
    shikimoriRating: details.scoreValue,
    internalRating: null,
    posterPath: null,
    posterThumbPath: null,
    backgroundPath: null,
    isOngoing: true,
    isInProduction: false,
    episodesTotal: 1,
    genres: const [],
    members: const [],
    episodes: const [
      AnimeEpisode(
        id: 'e1',
        ordinal: 1,
        name: 'серия 1',
        hls480: null,
        hls720: 'https://example.com/1.m3u8',
        hls1080: null,
        durationSeconds: null,
        previewPath: null,
        openingStart: null,
        openingStop: null,
        endingStart: null,
        endingStop: null,
        sortOrder: null,
      ),
    ],
    publishDay: null,
    blockedByGeo: false,
    blockedByCopyrights: false,
    freshAt: null,
    notification: null,
    shikimoriId: 42,
  );
  return AnimeWithSources(
    shikimoriAnime: details,
    sources: [
      AnimeSource(
        id: 'anilibria:42',
        shikimoriAnime: details,
        release: release,
        voiceover: const GenericVoiceover(
          id: 'anilibria_test',
          title: 'тест',
          subtitle: 'anilibria · тест',
          source: 'anilibria',
        ),
        sourceType: 'anilibria',
      ),
    ],
  );
}
