import 'package:anishka/core/sources/animevost_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('animevost episode parsing', () {
    test('parses inline ids with a trailing comma and sorts by ordinal', () {
      const html = '''
        <html>
          <script>
            var data = {"2 серия":"245477284","1 серия":"1451327130",};
          </script>
        </html>
      ''';

      final episodes = parseAnimeVostEpisodes(html);

      expect(episodes, hasLength(2));
      expect(episodes.map((episode) => episode.ordinal), [1, 2]);
      expect(episodes.first.externalId, '1451327130');
      expect(episodes.first.title, '1 серия');
      expect(
        episodes.first.posterUrl,
        'https://media.aniland.org/img/1451327130.jpg',
      );
      expect(episodes.last.externalId, '245477284');
    });

    test('falls back to insertion order when titles have no numbers', () {
      const html = 'var data = {"серия":"111","фильм":"222",};';

      final episodes = parseAnimeVostEpisodes(html);

      expect(episodes.map((episode) => episode.ordinal), [1, 2]);
      expect(episodes.map((episode) => episode.externalId), ['111', '222']);
    });

    test('returns no episodes for missing or malformed data', () {
      expect(parseAnimeVostEpisodes('<html></html>'), isEmpty);
      expect(parseAnimeVostEpisodes('var data = {broken json};'), isEmpty);
      expect(parseAnimeVostEpisodes('var data = {"1 серия":""};'), isEmpty);
    });
  });
}
