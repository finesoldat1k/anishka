import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'embed/embed_http.dart';
import 'resolved_stream.dart';
import 'source_provider.dart';
import 'unified_source.dart';

/// HDRezka source provider.
///
/// Search and details are scraped from the site; episode streams are obtained
/// from `/ajax/get_cdn_series/` on demand. All requests need a browser-like
/// user agent because the site rejects the default Dart one.
class HDRezka implements SourceProvider, StreamResolvableSourceProvider {
  HDRezka({Dio? dio}) : _dio = dio ?? _createDio();

  static const baseUrl = 'https://hdrezka-home.tv';
  static const _streamReferer = '$baseUrl/';

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 18),
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ),
    );
  }

  @override
  String get displayName => 'hdrezka';

  @override
  String get id => 'hdrezka';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    try {
      final response = await _dio.get<String>(
        '/search/',
        queryParameters: {
          'do': 'search',
          'subaction': 'search',
          'q': value,
        },
      );
      final body = response.data ?? '';
      if (body.isEmpty) return const [];
      final document = html_parser.parse(body);
      final results = <UnifiedSource>[];
      for (final item in document.querySelectorAll('.b-content__inline_item')) {
        final link = item.querySelector('.b-content__inline_item-link a');
        final rawUrl = item.attributes['data-url'] ??
            link?.attributes['href'] ??
            '';
        final url = absoluteUrl(rawUrl, base: baseUrl);
        if (url == null) continue;
        final title = (link?.text ?? item.text).trim();
        if (title.isEmpty) continue;
        final info = item.querySelector('span.info')?.text.trim();
        final image = item.querySelector('img')?.attributes['src'];
        results.add(
          UnifiedSource(
            id: _sourceId(url, '0'),
            providerId: 'hdrezka',
            title: title,
            subtitle: info == null || info.isEmpty
                ? 'hdrezka'
                : 'hdrezka · $info',
            logoUrl: absoluteUrl(image, base: baseUrl),
            requiresResolution: true,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    final hint = nameHint?.trim() ?? '';
    if (hint.isEmpty) return const [];
    final candidates = await search(hint);
    if (candidates.isEmpty) return const [];

    final ranked = [...candidates]
      ..sort((a, b) => _titleScore(b.title, hint)
          .compareTo(_titleScore(a.title, hint)));
    for (final candidate in ranked.take(3)) {
      if (_titleScore(candidate.title, hint) <= 0) continue;
      final url = _parseSourceId(candidate.id)?.url;
      if (url == null) continue;
      final page = await _fetchPage(url);
      if (page == null) continue;
      final sources = _buildSources(page, url);
      if (sources.isNotEmpty) return sources;
    }
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final parsed = _parseSourceId(sourceId);
    if (parsed == null) return null;
    final page = await _fetchPage(parsed.url);
    if (page == null) return null;
    final sources = _buildSources(page, parsed.url);
    if (sources.isEmpty) return null;
    for (final source in sources) {
      if (source.id == sourceId) return source;
    }
    return sources.first;
  }

  @override
  Future<ResolvedStream?> resolveStream(
    String sourceId, {
    int? ordinal,
    String quality = 'auto',
  }) async {
    final payload = _decodeResolverId(sourceId);
    if (payload == null) return null;
    try {
      final response = await _dio.post<String>(
        '/ajax/get_cdn_series/',
        queryParameters: {
          't': '${DateTime.now().millisecondsSinceEpoch - 40000}',
        },
        data: payload.isMovie
            ? {
                'id': payload.mediaId,
                'translator_id': payload.translatorId,
                'favs': payload.favs,
                'action': 'get_movie',
              }
            : {
                'id': payload.mediaId,
                'translator_id': payload.translatorId,
                'season': payload.seasonId,
                'episode': payload.episodeId,
                'favs': payload.favs,
                'action': 'get_stream',
              },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'X-Requested-With': 'XMLHttpRequest',
            'Origin': baseUrl,
            'Referer': payload.pageUrl,
          },
        ),
      );
      final body = response.data ?? '';
      if (!body.trimLeft().startsWith('{')) return null;
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      if (decoded['success'] == false) return null;
      final raw = decoded['url']?.toString() ?? '';
      final streams = parseStreams(raw);
      if (streams.isEmpty) return null;
      final key = pickQuality(streams.keys, requested: quality);
      if (key == null) return null;
      return streams[key]!.copyWith(quality: key, variants: streams);
    } catch (_) {
      return null;
    }
  }

  // ============ page parsing ============

  Future<_RezkaPage?> _fetchPage(String url) async {
    try {
      final response = await _dio.get<String>(url);
      final body = response.data ?? '';
      if (body.isEmpty) return null;
      final page = _RezkaPage.parse(body);
      if (page.title.isEmpty && page.id == 0) return null;
      return page;
    } catch (_) {
      return null;
    }
  }

  List<UnifiedSource> _buildSources(_RezkaPage page, String pageUrl) {
    final translations = page.translations.isNotEmpty
        ? page.translations
        : [
            _RezkaTranslation(
              title: 'hdrezka',
              id: page.defaultTranslatorId,
            ),
          ];

    final sources = <UnifiedSource>[];
    for (final translation in translations) {
      final episodes = <UnifiedEpisode>[];
      if (page.isSerial && page.episodes.isNotEmpty) {
        for (var index = 0; index < page.episodes.length; index++) {
          final episode = page.episodes[index];
          final ordinal = episode.episodeId > 0
              ? episode.episodeId
              : index + 1;
          final resolverId = _encodeResolverId(
            _RezkaResolverPayload(
              pageUrl: pageUrl,
              translatorId: translation.id,
              favs: page.favs,
              mediaId: '${page.id}',
              seasonId: '${episode.seasonId}',
              episodeId: '${episode.episodeId}',
              isMovie: false,
            ),
          );
          episodes.add(
            UnifiedEpisode(
              id: 'hdrezka:${page.id}:${translation.id}:${episode.seasonId}:${episode.episodeId}',
              ordinal: ordinal,
              title: episode.title.isEmpty ? 'серия $ordinal' : episode.title,
              posterUrl: page.thumbnail,
              resolverSource: 'hdrezka',
              resolverId: resolverId,
            ),
          );
        }
      } else {
        final resolverId = _encodeResolverId(
          _RezkaResolverPayload(
            pageUrl: pageUrl,
            translatorId: translation.id,
            favs: page.favs,
            mediaId: '${page.id}',
            seasonId: '0',
            episodeId: '0',
            isMovie: true,
          ),
        );
        episodes.add(
          UnifiedEpisode(
            id: 'hdrezka:${page.id}:${translation.id}:movie',
            ordinal: 1,
            title: 'фильм',
            posterUrl: page.thumbnail,
            resolverSource: 'hdrezka',
            resolverId: resolverId,
          ),
        );
      }

      sources.add(
        UnifiedSource(
          id: _sourceId(pageUrl, translation.id),
          providerId: 'hdrezka',
          title: translation.title.isEmpty ? 'hdrezka' : translation.title,
          subtitle: 'hdrezka · ${page.title}',
          logoUrl: page.thumbnail,
          episodeCount: episodes.length,
          episodes: episodes,
          hasDirectStreams: false,
          requiresResolution: true,
        ),
      );
    }
    return sources;
  }

  // ============ URL / payload encoding ============

  static String _sourceId(String url, String translatorId) {
    return 'hdrezka::${Uri.encodeComponent(url)}::$translatorId';
  }

  static ({String url, String translatorId})? _parseSourceId(
    String sourceId,
  ) {
    final parts = sourceId.split('::');
    if (parts.length < 3) return null;
    final url = Uri.decodeComponent(parts[1]);
    if (url.isEmpty) return null;
    return (url: url, translatorId: parts[2]);
  }

  static String _encodeResolverId(_RezkaResolverPayload payload) {
    String part(String value) => Uri.encodeComponent(value);
    return [
      'hdrezka',
      part(payload.pageUrl),
      part(payload.translatorId),
      part(payload.favs),
      part(payload.mediaId),
      part(payload.seasonId),
      part(payload.episodeId),
      payload.isMovie ? '1' : '0',
    ].join('|');
  }

  static _RezkaResolverPayload? _decodeResolverId(String value) {
    final parts = value.split('|');
    if (parts.length < 8 || parts.first != 'hdrezka') return null;
    String decode(int index) => Uri.decodeComponent(parts[index]);
    return _RezkaResolverPayload(
      pageUrl: decode(1),
      translatorId: decode(2),
      favs: decode(3),
      mediaId: decode(4),
      seasonId: decode(5),
      episodeId: decode(6),
      isMovie: parts[7] == '1',
    );
  }

  /// Parse the comma-separated `url` field of the CDN response.
  ///
  /// Items look like `[720p]https://...m3u8 or https://...mp4`.
  /// Exposed for tests.
  static Map<String, ResolvedStream> parseStreams(String raw) {
    final result = <String, ResolvedStream>{};
    for (final part in raw.split(',')) {
      final value = part.trim();
      if (value.isEmpty) continue;
      final match = RegExp(r'\[.*?(\d+).*?\]').firstMatch(value);
      if (match == null) continue;
      final quality = match.group(1)!;
      final after = value.substring(match.end).trim();
      final urls = after.split(' or ');
      for (final url in urls) {
        final trimmed = url.trim();
        if (trimmed.isEmpty) continue;
        final stream = ResolvedStream(
          url: trimmed,
          kind: StreamKind.fromUrl(trimmed),
          headers: const {'Referer': _streamReferer},
          quality: quality,
        );
        result.putIfAbsent(quality, () => stream);
        if (stream.kind == StreamKind.hls) {
          result[quality] = stream;
        }
      }
    }
    return result;
  }

  static int _titleScore(String title, String query) {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final left = normalize(title);
    final right = normalize(query);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 100;
    if (left.contains(right) || right.contains(left)) return 60;
    final leftWords = left.split(' ').toSet();
    final rightWords = right.split(' ').toSet();
    final common = leftWords.intersection(rightWords).length;
    return common * 10;
  }
}

class _RezkaPage {
  const _RezkaPage({
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.favs,
    required this.id,
    required this.defaultTranslatorId,
    required this.translations,
    required this.episodes,
    required this.isSerial,
  });

  final String title;
  final String description;
  final String? thumbnail;
  final String favs;
  final int id;
  final String defaultTranslatorId;
  final List<_RezkaTranslation> translations;
  final List<_RezkaEpisode> episodes;
  final bool isSerial;

  static _RezkaPage parse(String body) {
    final document = html_parser.parse(body);
    final title = document.querySelector('.b-post__title h1')?.text.trim() ?? '';
    final description =
        document.querySelector('.b-post__description_text')?.text.trim() ?? '';
    final thumbnail =
        document.querySelector('img[data-caption-title][src]')?.attributes['src'];
    final favs =
        document.querySelector('input#ctrl_favs[value]')?.attributes['value'] ??
            '';

    final translations = <_RezkaTranslation>[];
    for (final item in document.querySelectorAll(
      '#translators-list > li.b-translator__item',
    )) {
      translations.add(
        _RezkaTranslation(
          title: (item.attributes['title'] ?? item.text).trim(),
          id: item.attributes['data-translator_id'] ?? '',
        ),
      );
    }

    final episodes = <_RezkaEpisode>[];
    for (final item in document.querySelectorAll(
      '.b-simple_episodes__list .b-simple_episode__item',
    )) {
      episodes.add(
        _RezkaEpisode(
          title: item.text.trim(),
          seasonId: int.tryParse(item.attributes['data-season_id'] ?? '') ?? 0,
          episodeId:
              int.tryParse(item.attributes['data-episode_id'] ?? '') ?? 0,
        ),
      );
    }

    var mediaId = 0;
    var translatorId = '';
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final text = script.text;
      if (!text.contains('initCDNSeriesEvents') &&
          !text.contains('initCDNMoviesEvents')) {
        continue;
      }
      final idMatch =
          RegExp(r'initCDN(?:Series|Movies)Events\(\s*(\d+)').firstMatch(text);
      if (idMatch != null) mediaId = int.tryParse(idMatch.group(1)!) ?? 0;
      final translatorMatch = RegExp(
        r'initCDN(?:Series|Movies)Events\(\s*\d+\s*,\s*(\d+)',
      ).firstMatch(text);
      if (translatorMatch != null) translatorId = translatorMatch.group(1)!;
      break;
    }

    // Fall back to the first episode's media id when the script is missing.
    if (mediaId == 0) {
      final first = document.querySelector(
        '.b-simple_episodes__list .b-simple_episode__item[data-id]',
      );
      mediaId = int.tryParse(first?.attributes['data-id'] ?? '') ?? 0;
    }

    return _RezkaPage(
      title: title,
      description: description,
      thumbnail: absoluteUrl(thumbnail, base: HDRezka.baseUrl),
      favs: favs,
      id: mediaId,
      defaultTranslatorId: translatorId,
      translations: translations,
      episodes: episodes,
      isSerial: episodes.isNotEmpty,
    );
  }
}

class _RezkaTranslation {
  const _RezkaTranslation({required this.title, required this.id});

  final String title;
  final String id;
}

class _RezkaEpisode {
  const _RezkaEpisode({
    required this.title,
    required this.seasonId,
    required this.episodeId,
  });

  final String title;
  final int seasonId;
  final int episodeId;
}

class _RezkaResolverPayload {
  const _RezkaResolverPayload({
    required this.pageUrl,
    required this.translatorId,
    required this.favs,
    required this.mediaId,
    required this.seasonId,
    required this.episodeId,
    required this.isMovie,
  });

  final String pageUrl;
  final String translatorId;
  final String favs;
  final String mediaId;
  final String seasonId;
  final String episodeId;
  final bool isMovie;
}
