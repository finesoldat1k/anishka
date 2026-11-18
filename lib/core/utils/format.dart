extension LowercaseText on String {
  /// весь текст интерфейса и контента в anishka пишется строчными.
  String get lc => toLowerCase();
}

String lc(String? value, {String fallback = ''}) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return fallback;
  return text.toLowerCase();
}

String? lcOrNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text.toLowerCase();
}

String formatScore(double? score) {
  if (score == null || score <= 0) return '—';
  return score.toStringAsFixed(1);
}

String formatNumber(int? value) {
  if (value == null) return '—';
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String releasesLabel(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  final word = (mod100 >= 11 && mod100 <= 14)
      ? 'релизов'
      : switch (mod10) {
          1 => 'релиз',
          2 || 3 || 4 => 'релиза',
          _ => 'релизов',
        };
  return '$count $word';
}

String episodesLabel(int? count) {
  if (count == null || count <= 0) return 'серии ещё не вышли';
  final mod100 = count % 100;
  final mod10 = count % 10;
  final word = (mod100 >= 11 && mod100 <= 14)
      ? 'серий'
      : switch (mod10) {
          1 => 'серия',
          2 || 3 || 4 => 'серии',
          _ => 'серий',
        };
  return '$count $word';
}

String formatDuration(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$mm:$ss';
}

String releaseMeta({int? year, String? type, String? season, int? episodes}) {
  final parts = <String>[
    if (year != null && year > 0) '$year',
    if (type != null && type.trim().isNotEmpty) lc(type),
    if (season != null && season.trim().isNotEmpty) lc(season),
    if (episodes != null && episodes > 0) episodesLabel(episodes),
  ];
  return parts.join(' · ');
}
