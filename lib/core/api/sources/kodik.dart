import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../json_utils.dart';
import 'embed/kodik_resolver.dart';
import 'resolved_stream.dart';
import 'source_provider.dart';
import 'unified_source.dart';

/// Kodik source provider.
///
/// Uses the public Kodik search API (requires a token) to find translations
/// for a Shikimori id, then reads the embed page once per title to build real
/// season/episode lists. Playback is resolved through [KodikResolver].
class Kodik implements SourceProvider, StreamResolvableSourceProvider {
  Kodik({Dio? dio, KodikResolver? resolver})
      : _dio = dio ?? _createDio(),
        _resolver = resolver ?? KodikResolver();

  final Dio _dio;
  final KodikResolver _resolver;

  static const _apiBase = 'https://kodik-api.com';

  /// Stable token from `kdk_tokns/tokens.json` (checked 2026-04).
  static const _fallbackTokens = <String>[
    '56a768d08f43091901c44b54fe970049',
    '41dd95f84c21719b09d6c71182237a25',
    '77b567ec164db6ca9162d2f3dc4948c3',
    '447d179e875efe44217f20d1ee2146be',
  ];

  static const _tokenUrls = <String>[
    'https://cdn.jsdelivr.net/gh/YaNesyTortiK/AnimeParsers@main/kdk_tokns/tokens.json',
    'https://raw.githubusercontent.com/YaNesyTortiK/AnimeParsers/main/kdk_tokns/tokens.json',
  ];

  List<String> _tokens = [..._fallbackTokens];
  bool _tokensLoaded = false;
  final Map<String, _KodikEmbed> _embedCache = {};

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: _apiBase,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 18),
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Accept-Language': 'ru-RU,ru;q=0.9',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ),
    );
  }

  @override
  String get displayName => 'kodik';

  @override
  String get id => 'kodik';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final data = await _apiSearch({'title': value});
    return _buildSources(data);
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    var data = await _apiSearch({'shikimori_id': '$shikimoriId'});
    if (data.isEmpty && nameHint != null && nameHint.trim().isNotEmpty) {
      data = await _apiSearch({'title': nameHint.trim()});
    }
    return _buildSources(data);
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final parsed = _parseSourceId(sourceId);
    if (parsed == null) return null;
    final data = await _apiSearch({'id': parsed.mediaId});
    final sources = await _buildSources(data);
    for (final source in sources) {
      if (source.id == sourceId) return source;
    }
    for (final source in sources) {
      if (source.title == parsed.translationTitle) return source;
    }
    return sources.isEmpty ? null : sources.first;
  }

  @override
  Future<ResolvedStream?> resolveStream(
    String sourceId, {
    int? ordinal,
    String quality = 'auto',
  }) {
    return _resolver.resolve(sourceId, quality: quality);
  }

  // ============ API ============

  Future<List<Map<String, dynamic>>> _apiSearch(
    Map<String, String> filters,
  ) async {
    await _loadTokens();
    final seen = <String>{};
    for (final token in _tokens) {
      if (!seen.add(token)) continue;
      try {
        final response = await _dio.post<String>(
          '/search',
          data: {
            'token': token,
            ...filters,
            'limit': '50',
            'with_material_data': 'true',
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain,
          ),
        );
        final body = response.data ?? '';
        if (!body.trimLeft().startsWith('{')) continue;
        final decoded = jsonDecode(body);
        if (decoded is! Map) continue;
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) {
          // Invalid/expired token: try the next one.
          continue;
        }
        final results = decoded['results'];
        if (results is List) {
          // Promote the working token to the front.
          _tokens.remove(token);
          _tokens.insert(0, token);
          return results
              .whereType<Map>()
              .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
              .toList();
        }
      } catch (_) {
        // Try the next token.
      }
    }
    return const [];
  }

  Future<void> _loadTokens() async {
    if (_tokensLoaded) return;
    _tokensLoaded = true;
    for (final url in _tokenUrls) {
      try {
        final response = await _dio
            .get<String>(url, options: Options(responseType: ResponseType.plain))
            .timeout(const Duration(seconds: 6));
        final body = response.data ?? '';
        if (!body.trimLeft().startsWith('{')) continue;
        final decoded = jsonDecode(body);
        if (decoded is! Map) continue;
        final loaded = <String>[];
        for (final group in const ['stable', 'unstable', 'legacy']) {
          final items = decoded[group];
          if (items is! List) continue;
          for (final item in items) {
            final raw = item is Map ? item['tokn']?.toString() : null;
            if (raw == null || raw.isEmpty) continue;
            final token = decryptToken(raw);
            if (token != null && token.isNotEmpty) loaded.add(token);
          }
        }
        if (loaded.isNotEmpty) {
          _tokens = [...loaded, ..._fallbackTokens];
          return;
        }
      } catch (_) {
        // Try the next mirror.
      }
    }
  }

  /// Decode a token from `kdk_tokns/tokens.json`.
  static String? decryptToken(String value) {
    try {
      final half = value.length ~/ 2;
      final first = base64.decode(_reverse(value.substring(0, half)));
      final second = base64.decode(_reverse(value.substring(half)));
      return '${utf8.decode(second)}${utf8.decode(first)}';
    } catch (_) {
      return null;
    }
  }

  static String _reverse(String value) =>
      String.fromCharCodes(value.codeUnits.reversed);

  // ============ source building ============

  Future<List<UnifiedSource>> _buildSources(
    List<Map<String, dynamic>> results,
  ) async {
    if (results.isEmpty) return const [];

    // Kodik returns one row per translation. Rows for the same season share
    // the same embed page, so group them and read that page once instead of
    // fetching it for every translation.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final result in results) {
      final title = result['title']?.toString() ?? '';
      final year = result['year']?.toString() ?? '';
      final type = result['type']?.toString() ?? '';
      final season = result['last_season']?.toString() ?? '';
      final key = '$title|$year|$type|$season';
      grouped.putIfAbsent(key, () => []).add(result);
    }

    final sources = <UnifiedSource>[];
    for (final group in grouped.values) {
      final first = group.first;
      final groupId = first['id']?.toString() ?? '';
      if (groupId.isEmpty) continue;
      final link = _absoluteLink(first['link']?.toString());
      final title = first['title']?.toString() ?? '';
      final screenshots = (first['screenshots'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const <String>[];

      _KodikEmbed? embed;
      if (link != null) {
        embed = _embedCache[link];
        if (embed == null) {
          embed = await _fetchEmbed(link);
          if (embed != null) _embedCache[link] = embed;
        }
      }

      if (embed != null && embed.translations.isNotEmpty) {
        final apiByTranslation = <String, Map<String, dynamic>>{};
        for (final result in group) {
          final translation = result['translation'];
          if (translation is! Map) continue;
          final id = translation['id']?.toString() ?? '';
          final name = translation['title']?.toString() ?? '';
          apiByTranslation['$id::$name'] = result;
        }
        for (final translation in embed.translations) {
          final episodes = _buildEpisodes(
            embed: embed,
            translation: translation,
            mediaId: groupId,
            fallbackLink: link,
            apiResult: apiByTranslation['${translation.id}::${translation.name}'],
          );
          if (episodes.isEmpty) continue;
          sources.add(
            UnifiedSource(
              id: _sourceId(groupId, translation.id, translation.name),
              providerId: 'kodik',
              title: translation.name.isEmpty ? 'kodik' : translation.name,
              subtitle: 'kodik · $title',
              logoUrl: screenshots.isNotEmpty ? screenshots.first : null,
              episodeCount: episodes.length,
              episodes: episodes,
              hasDirectStreams: false,
              requiresResolution: true,
            ),
          );
        }
        continue;
      }

      // Embed unavailable: build the episode list from the search payload so
      // a translation still exposes every known episode instead of one.
      for (final result in group) {
        final resultLink = _absoluteLink(result['link']?.toString());
        if (resultLink == null) continue;
        final translation = result['translation'];
        final translationTitle = translation is Map
            ? (translation['title']?.toString() ?? 'kodik')
            : 'kodik';
        final translationId = translation is Map
            ? (translation['id']?.toString() ?? '0')
            : '0';
        final episodes = _fallbackEpisodes(
          result: result,
          link: resultLink,
          mediaId: groupId,
          translationId: translationId,
          title: translationTitle,
          poster: screenshots.isNotEmpty ? screenshots.first : null,
        );
        if (episodes.isEmpty) continue;
        sources.add(
          UnifiedSource(
            id: _sourceId(groupId, translationId, translationTitle),
            providerId: 'kodik',
            title: translationTitle,
            subtitle: 'kodik · $title',
            logoUrl: screenshots.isNotEmpty ? screenshots.first : null,
            episodeCount: episodes.length,
            episodes: episodes,
            hasDirectStreams: false,
            requiresResolution: true,
          ),
        );
      }
    }
    return sources;
  }

  List<UnifiedEpisode> _fallbackEpisodes({
    required Map<String, dynamic> result,
    required String link,
    required String mediaId,
    required String translationId,
    required String title,
    required String? poster,
  }) {
    final type = result['type']?.toString() ?? '';
    final isSerial = type.contains('serial') || type.contains('season');
    if (!isSerial) {
      return [
        UnifiedEpisode(
          id: 'kodik:$mediaId:$translationId:1',
          ordinal: 1,
          title: 'фильм',
          posterUrl: poster,
          embedUrl: link,
          embedLabel: title,
          resolverSource: 'kodik',
          resolverId: link,
        ),
      ];
    }

    final season = asInt(result['last_season']) ?? 1;
    final count = asInt(result['episodes_count']) ?? 0;
    final last = asInt(result['last_episode']) ?? count;
    if (count <= 0 || last <= 0) {
      final url = _episodeLink(link, season, 1) ?? link;
      return [
        UnifiedEpisode(
          id: 'kodik:$mediaId:$translationId:$season:1',
          ordinal: 1,
          title: 'серия 1',
          posterUrl: poster,
          embedUrl: url,
          embedLabel: title,
          resolverSource: 'kodik',
          resolverId: url,
        ),
      ];
    }

    final start = last - count + 1;
    final first = start < 1 ? 1 : start;
    final episodes = <UnifiedEpisode>[];
    for (var ordinal = first; ordinal <= last; ordinal++) {
      final url = _episodeLink(link, season, ordinal);
      if (url == null) continue;
      episodes.add(
        UnifiedEpisode(
          id: 'kodik:$mediaId:$translationId:$season:$ordinal',
          ordinal: ordinal,
          title: 'серия $ordinal',
          posterUrl: poster,
          embedUrl: url,
          embedLabel: title,
          resolverSource: 'kodik',
          resolverId: url,
        ),
      );
    }
    return episodes;
  }

  static String? _episodeLink(String link, int season, int ordinal) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'season': '$season',
            'episode': '$ordinal',
          },
        )
        .toString();
  }

  List<UnifiedEpisode> _buildEpisodes({
    required _KodikEmbed embed,
    required _KodikTranslation translation,
    required String mediaId,
    required String? fallbackLink,
    Map<String, dynamic>? apiResult,
  }) {
    final id = translation.mediaId.isNotEmpty ? translation.mediaId : mediaId;
    final hash = translation.mediaHash;
    final episodes = <UnifiedEpisode>[];

    // The embed page is rendered for one selected translation and lists the
    // whole season, so limit it to each translation's own episode range.
    final apiCount = asInt(apiResult?['episodes_count']) ?? 0;
    final apiLast = asInt(apiResult?['last_episode']) ?? 0;
    final declaredCount = apiCount > 0 ? apiCount : translation.episodeCount;
    final declaredLast = apiLast > 0 ? apiLast : declaredCount;
    final declaredStart = declaredLast - declaredCount + 1;

    if (embed.isSerial) {
      final seasons = embed.seasons;
      final seriesBySeason = embed.episodesBySeason;
      final total = declaredCount;

      if (seriesBySeason.isNotEmpty) {
        for (final entry in seriesBySeason.entries) {
          final season = entry.key;
          for (final ordinal in entry.value) {
            if (declaredCount > 0 &&
                (ordinal < declaredStart || ordinal > declaredLast)) {
              continue;
            }
            final url = _serialUrl(embed.netloc, id, hash, season, ordinal);
            if (url == null) continue;
            episodes.add(
              _episode(
                mediaId: mediaId,
                translationId: translation.id,
                season: season,
                ordinal: ordinal,
                url: url,
                multiSeason: seriesBySeason.length > 1,
              ),
            );
          }
        }
      } else {
        final seasonList = seasons.isEmpty ? [1] : seasons;
        final perSeason = seasonList.length <= 1
            ? total
            : (total / seasonList.length).ceil();
        for (final season in seasonList) {
          final count = perSeason <= 0 ? 1 : perSeason;
          final start = seasonList.length <= 1 && declaredStart > 1
              ? declaredStart
              : 1;
          final end = start + count - 1;
          for (var ordinal = start; ordinal <= end; ordinal++) {
            final url = _serialUrl(embed.netloc, id, hash, season, ordinal);
            if (url == null) continue;
            episodes.add(
              _episode(
                mediaId: mediaId,
                translationId: translation.id,
                season: season,
                ordinal: ordinal,
                url: url,
                multiSeason: seasonList.length > 1,
              ),
            );
          }
        }
      }
    } else {
      final url = _movieUrl(embed.netloc, id, hash) ?? fallbackLink;
      if (url != null) {
        episodes.add(
          UnifiedEpisode(
            id: 'kodik:$mediaId:${translation.id}:1',
            ordinal: 1,
            title: 'фильм',
            embedUrl: url,
            embedLabel: translation.name,
            resolverSource: 'kodik',
            resolverId: url,
          ),
        );
      }
    }
    episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return episodes;
  }

  UnifiedEpisode _episode({
    required String mediaId,
    required String translationId,
    required int season,
    required int ordinal,
    required String url,
    required bool multiSeason,
  }) {
    return UnifiedEpisode(
      id: 'kodik:$mediaId:$translationId:$season:$ordinal',
      ordinal: ordinal,
      title: multiSeason ? 'сезон $season · серия $ordinal' : 'серия $ordinal',
      embedUrl: url,
      resolverSource: 'kodik',
      resolverId: url,
    );
  }

  Future<_KodikEmbed?> _fetchEmbed(String link) async {
    try {
      final response = await _dio.get<String>(
        link,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Referer': 'https://kodik.info/'},
        ),
      );
      final body = response.data ?? '';
      if (body.isEmpty ||
          body.contains('Видео не найдено') ||
          body.contains('Видео запрещено к просмотру')) {
        return null;
      }
      return _KodikEmbed.parse(body, link);
    } catch (_) {
      return null;
    }
  }

  static String? _serialUrl(
    String netloc,
    String mediaId,
    String hash,
    int season,
    int episode,
  ) {
    if (netloc.isEmpty || mediaId.isEmpty || hash.isEmpty) return null;
    return 'https://$netloc/serial/$mediaId/$hash/720p'
        '?season=$season&episode=$episode';
  }

  static String? _movieUrl(String netloc, String mediaId, String hash) {
    if (netloc.isEmpty || mediaId.isEmpty || hash.isEmpty) return null;
    return 'https://$netloc/video/$mediaId/$hash/720p';
  }

  static String? _absoluteLink(String? link) {
    if (link == null) return null;
    final value = link.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('http')) return value;
    return 'https://$value';
  }

  static String _sourceId(
    String mediaId,
    String translationId,
    String translationTitle,
  ) {
    return 'kodik::$mediaId::$translationId::${Uri.encodeComponent(translationTitle)}';
  }

  static ({String mediaId, String translationTitle})? _parseSourceId(
    String sourceId,
  ) {
    final parts = sourceId.split('::');
    if (parts.length < 3) return null;
    return (
      mediaId: parts[1],
      translationTitle:
          parts.length > 3 ? Uri.decodeComponent(parts[3]) : '',
    );
  }
}

class _KodikEmbed {
  const _KodikEmbed({
    required this.netloc,
    required this.isSerial,
    required this.translations,
    required this.seasons,
    required this.episodesBySeason,
  });

  final String netloc;
  final bool isSerial;
  final List<_KodikTranslation> translations;
  final List<int> seasons;
  final Map<int, List<int>> episodesBySeason;

  static _KodikEmbed? parse(String body, String link) {
    try {
      final uri = Uri.tryParse(link);
      final netloc = uri?.host ?? 'kodik.info';
      final path = uri?.path ?? '';
      final isSerial = path.contains('/serial/') || path.contains('/season/');

      final document = html_parser.parse(body);
      final translationBox = document.querySelector(
            '.serial-translations-box option',
          ) !=
          null
          ? '.serial-translations-box option'
          : '.movie-translations-box option';
      final translations = <_KodikTranslation>[];
      for (final option in document.querySelectorAll(translationBox)) {
        final mediaId = option.attributes['data-media-id'] ?? '';
        final mediaHash = option.attributes['data-media-hash'] ?? '';
        final id = option.attributes['value'] ?? '';
        if (id.isEmpty && mediaId.isEmpty) continue;
        translations.add(
          _KodikTranslation(
            id: id,
            name: (option.attributes['data-title'] ?? option.text).trim(),
            mediaId: mediaId,
            mediaHash: mediaHash,
            episodeCount: _episodeCount(option),
          ),
        );
      }

      final seasons = <int>[];
      for (final option in document.querySelectorAll(
        '.serial-seasons-box option',
      )) {
        final value = int.tryParse(option.attributes['value'] ?? '');
        if (value != null) seasons.add(value);
      }

      final episodesBySeason = <int, List<int>>{};
      final optionGroups = document.querySelectorAll('.series-options > div');
      for (var index = 0; index < optionGroups.length; index++) {
        final group = optionGroups[index];
        final className = group.attributes['class'] ?? '';
        final match = RegExp(r'(?:season|series)[-_]?(\d+)').firstMatch(className);
        final season = int.tryParse(match?.group(1) ?? '') ?? index + 1;
        final ordinals = <int>[];
        for (final option in group.querySelectorAll('option')) {
          final value = int.tryParse(option.attributes['value'] ?? '');
          if (value != null && value > 0) ordinals.add(value);
        }
        if (ordinals.isNotEmpty) {
          ordinals.sort();
          episodesBySeason[season] = ordinals;
        }
      }

      if (translations.isEmpty) return null;
      return _KodikEmbed(
        netloc: netloc,
        isSerial: isSerial,
        translations: translations,
        seasons: seasons,
        episodesBySeason: episodesBySeason,
      );
    } catch (_) {
      return null;
    }
  }

  static int _episodeCount(dom.Element option) {
    final raw = option.attributes['data-episode-count'];
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null && parsed > 0) return parsed;
    final text = option.text;
    final range = RegExp(r'\((\d+)\s*[-~]\s*(\d+)\s*эп').firstMatch(text);
    if (range != null) {
      return int.tryParse(range.group(2)!) ?? 0;
    }
    final single = RegExp(r'\((\d+)\s*эп').firstMatch(text);
    if (single != null) return int.tryParse(single.group(1)!) ?? 0;
    return 0;
  }
}

class _KodikTranslation {
  const _KodikTranslation({
    required this.id,
    required this.name,
    required this.mediaId,
    required this.mediaHash,
    required this.episodeCount,
  });

  final String id;
  final String name;
  final String mediaId;
  final String mediaHash;
  final int episodeCount;
}
