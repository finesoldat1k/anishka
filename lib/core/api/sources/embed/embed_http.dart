import 'dart:convert';

import 'package:dio/dio.dart';

/// Browser-like user agent shared by all scrapers. Several CDNs reject the
/// default Dart/Flutter agent or return a stripped-down page.
const embedUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

Dio createEmbedDio({String? baseUrl, Map<String, String>? headers}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'User-Agent': embedUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        ...?headers,
      },
    ),
  );
}

/// Convert a possibly protocol-relative or relative URL into an absolute one.
String? absoluteUrl(String? raw, {String? base}) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) return 'https:$value';
  if (base == null || base.isEmpty) return null;
  final parsedBase = Uri.tryParse(base);
  if (parsedBase == null) return null;
  return parsedBase.resolve(value).toString();
}

/// Decode an HTML attribute/entity-encoded JSON string if needed.
String unescapeHtml(String value) {
  return value
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

/// First capture group of [pattern] in [text], or null.
String? firstMatch(RegExp pattern, String text) {
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  if (match.groupCount >= 1) return match.group(1);
  return match.group(0);
}

/// ROT-18 used by Kodik for encoded video URLs.
String rot18(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 65 && rune <= 90) {
      buffer.writeCharCode((rune - 65 + 18) % 26 + 65);
    } else if (rune >= 97 && rune <= 122) {
      buffer.writeCharCode((rune - 97 + 18) % 26 + 97);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Decode a Kodik-encoded URL (ROT-18 + base64, or a plain `.m3u8`).
String? decodeKodikUrl(String encoded) {
  final value = encoded.trim();
  if (value.isEmpty) return null;
  if (value.endsWith('.m3u8')) {
    return value.startsWith('https') ? value : 'https:$value';
  }
  var base64Url = rot18(value);
  while (base64Url.length % 4 != 0) {
    base64Url += '=';
  }
  try {
    final decoded = utf8.decode(base64.decode(base64Url));
    if (decoded.isEmpty) return null;
    return decoded.startsWith('https') ? decoded : 'https:$decoded';
  } catch (_) {
    return null;
  }
}

/// Parse a quality label into a comparable integer (1080, 720, ...).
int qualityRank(String? value) {
  if (value == null) return 0;
  final match = RegExp(r'(\d{3,4})').firstMatch(value);
  return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
}

/// Pick the key closest to [requested] from [available].
///
/// `auto` prefers the highest quality, otherwise the closest rank is used
/// (preferring a higher quality on ties).
String? pickQuality(
  Iterable<String> available, {
  String requested = 'auto',
}) {
  final keys = available.where((key) => key.trim().isNotEmpty).toList();
  if (keys.isEmpty) return null;
  if (requested == 'auto') {
    keys.sort((a, b) => qualityRank(b).compareTo(qualityRank(a)));
    return keys.first;
  }
  final wanted = qualityRank(requested);
  if (wanted <= 0) return keys.first;
  keys.sort((a, b) {
    final delta = (qualityRank(a) - wanted).abs().compareTo(
          (qualityRank(b) - wanted).abs(),
        );
    if (delta != 0) return delta;
    return qualityRank(b).compareTo(qualityRank(a));
  });
  return keys.first;
}
