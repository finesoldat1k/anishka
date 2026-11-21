/// Cleans descriptions coming from Shikimori, AniList, Kitsu and AniLibria.
///
/// Providers mix plain text with BBCode-style tags (`[character=4883]…`),
/// HTML (`<br>`, `<i>`), entities and Japanese name readings in square
/// brackets (`[モンキー・D・ルフィ]`). Leftovers look like broken markup in
/// the UI, so everything is normalised here.
String cleanAnimeDescription(String? raw, {bool collapseWhitespace = true}) {
  if (raw == null) return '';
  var text = raw.trim();
  if (text.isEmpty) return '';

  // HTML line breaks should stay line breaks before tags are stripped.
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');

  const entities = {
    '&amp;': '&',
    '&quot;': '"',
    '&#039;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
    '&hellip;': '…',
    '&mdash;': '—',
    '&ndash;': '–',
  };
  for (final entry in entities.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  // BBCode tags: [b], [/b], [character=4883], [url=…], [spoiler]…
  text = text.replaceAll(
    RegExp(
      r'\[/?(character|anime|manga|person|ranobe|url|b|i|u|s|spoiler|quote'
      r'|code|align|center|left|right|size|color|font|email|img|video|audio)'
      r'(?:=[^\]]*)?\]',
      caseSensitive: false,
    ),
    '',
  );

  // Any remaining simple [tag] / [tag=value] patterns.
  text = text.replaceAll(
    RegExp(r'\[/?[a-z]+(?:=[^\]]*)?\]', caseSensitive: false),
    '',
  );

  // Japanese readings/transliterations in square brackets, e.g.
  // `Монки Д. Луффи [モンキー・D・ルフィ]`. The body font has no CJK glyphs,
  // so keeping them renders as tofu boxes.
  text = text.replaceAll(
    RegExp(
      r'\s*\[[^\]]*[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]'
      r'[^\]]*\]',
    ),
    '',
  );

  if (collapseWhitespace) {
    text = text.replaceAll(RegExp(r'\s+'), ' ');
  } else {
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  return text.trim();
}
