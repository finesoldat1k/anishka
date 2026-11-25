import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:anishka/core/models/anime_episode.dart';
import 'package:anishka/core/theme/app_theme.dart';
import 'package:anishka/features/player/episode_picker_sheet.dart';

AnimeEpisode episode(int ordinal) {
  return AnimeEpisode(
    id: 'episode-$ordinal',
    ordinal: ordinal,
    name: null,
    hls480: null,
    hls720: null,
    hls1080: 'https://example.com/$ordinal.m3u8',
    durationSeconds: 1440,
    previewPath: null,
    openingStart: null,
    openingStop: null,
    endingStart: null,
    endingStop: null,
    sortOrder: ordinal,
  );
}

void main() {
  testWidgets('picker lists only episodes and plays the tapped one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AnimeEpisode? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showEpisodePickerSheet(
                  context,
                  episodes: [episode(1), episode(2), episode(3)],
                  voiceTitle: 'студия',
                  currentOrdinal: 2,
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    expect(find.text('серии'), findsOneWidget);
    expect(find.text('озвучка: студия'), findsOneWidget);
    // Voiceover chips are gone: only the fixed voice label is present.
    expect(find.text('студия'), findsNothing);
    expect(find.text('сейчас'), findsOneWidget);

    await tester.tap(find.text('серия 3').first);
    await tester.pumpAndSettle();

    expect(selected?.ordinal, 3);
    expect(find.text('озвучка: студия'), findsNothing);
  });

  testWidgets('tapping the current episode keeps the same selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AnimeEpisode? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showEpisodePickerSheet(
                  context,
                  episodes: [episode(1), episode(2)],
                  voiceTitle: 'студия',
                  currentOrdinal: 2,
                );
              },
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('серия 2').first);
    await tester.pumpAndSettle();

    expect(selected?.ordinal, 2);
    // The caller skips restarting when the ordinal matches.
    expect(find.text('озвучка: студия'), findsNothing);
  });
}
