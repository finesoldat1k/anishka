import 'package:anishka/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lowercases interface and content text', () {
    expect(lc('ПРИВЕТ'), 'привет');
    expect(lc('  '), '');
    expect(lc(null, fallback: 'нет'), 'нет');
    expect(lcOrNull(' ТЕКСТ '), 'текст');
    expect(lcOrNull('   '), isNull);
  });

  test('formats durations for player labels', () {
    expect(formatDuration(const Duration(seconds: 7)), '0:07');
    expect(formatDuration(const Duration(minutes: 2, seconds: 9)), '2:09');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 4, seconds: 5)),
      '1:04:05',
    );
  });

  test('formats scores and russian plural labels', () {
    expect(formatScore(8.46), '8.5');
    expect(formatScore(null), '—');
    expect(formatScore(0), '—');
    expect(releasesLabel(1), '1 релиз');
    expect(releasesLabel(3), '3 релиза');
    expect(releasesLabel(11), '11 релизов');
    expect(releasesLabel(22), '22 релиза');
    expect(episodesLabel(1), '1 серия');
    expect(episodesLabel(2), '2 серии');
    expect(episodesLabel(5), '5 серий');
    expect(episodesLabel(null), 'серии ещё не вышли');
  });

  test('builds a lowercase release meta line', () {
    expect(
      releaseMeta(year: 2025, type: 'TV', season: 'ВЕСНА', episodes: 12),
      '2025 · tv · весна · 12 серий',
    );
    expect(releaseMeta(), '');
  });
}
