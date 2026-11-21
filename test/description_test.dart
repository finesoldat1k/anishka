import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/utils/description.dart';

void main() {
  test('removes shikimori character tags but keeps their text', () {
    const raw =
        '[character=4883]Роджер Гол Д.[/character] стал королём пиратов.';
    expect(cleanAnimeDescription(raw), 'Роджер Гол Д. стал королём пиратов.');
  });

  test('removes formatting tags and japanese readings', () {
    const raw = '[b]Монки Д. Луффи[/b] [モンキー・D・ルフィ], мальчик [i]со шляпой[/i].';
    expect(cleanAnimeDescription(raw), 'Монки Д. Луффи, мальчик со шляпой.');
  });

  test('converts html breaks and entities', () {
    const raw = 'Первая строка<br>вторая &amp; третья&hellip;';
    expect(cleanAnimeDescription(raw), 'Первая строка вторая & третья…');
  });

  test('returns an empty string for empty input', () {
    expect(cleanAnimeDescription(null), '');
    expect(cleanAnimeDescription('   '), '');
    expect(cleanAnimeDescription('[b][/b]'), '');
  });
}
