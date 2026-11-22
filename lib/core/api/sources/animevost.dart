import 'dart:convert';

import 'package:dio/dio.dart';

import '../json_utils.dart';
import 'source_provider.dart';
import 'unified_source.dart';

/// AnimeVost source provider (`api.animevost.org`).
///
/// The API returns direct MP4 links for `std` (480p) and `hd` (720p).
class AnimeVost implements SourceProvider {
  AnimeVost({Dio? dio}) : _dio = dio ?? _createDio();

  static const apiBase = 'https://api.animevost.org';

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: apiBase,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 18),
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      ),
    );
  }

  @override
  String get displayName => 'animevost';

  @override
  String get id => 'animevost';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final data = await _post('/v1/search', {'name': value});
    if (data is! Map) return const [];
    if (data['error'] != null) return const [];
    final items = asMapList(data['data']);
    final results = <UnifiedSource>[];
    for (final item in items) {
      final id = asInt(item['id']);
      final title = item['title']?.toString().trim() ?? '';
      if (id == null || id <= 0 || title.isEmpty) continue;
      results.add(
        UnifiedSource(
          id: _sourceId(id),
          providerId: 'animevost',
          title: title,
          subtitle: 'animevost',
          logoUrl: _absolute(item['urlImagePreview']?.toString()),
        ),
      );
    }
    return results;
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
      final id = _parseSourceId(candidate.id);
      if (id == null) continue;
      final source = await _buildSource(id, title: candidate.title);
      if (source != null && source.episodes.isNotEmpty) return [source];
    }
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    final id = _parseSourceId(sourceId);
    if (id == null) return null;
    return _buildSource(id);
  }

  Future<UnifiedSource?> _buildSource(int id, {String? title}) async {
    final data = await _post('/v1/playlist', {'id': '$id'});
    final items = asMapList(data is List ? data : (data is Map ? data['data'] : null));
    if (items.isEmpty) return null;

    final episodes = <UnifiedEpisode>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final ordinal = index + 1;
      final hd = _absolute(item['hd']?.toString());
      final std = _absolute(item['std']?.toString());
      if (hd == null && std == null) continue;
      episodes.add(
        UnifiedEpisode(
          id: 'animevost:$id:$ordinal',
          ordinal: ordinal,
          title: item['name']?.toString().trim().isNotEmpty == true
              ? item['name'].toString().trim()
              : 'серия $ordinal',
          posterUrl: _absolute(item['preview']?.toString()),
          hls480: std,
          hls720: hd,
        ),
      );
    }
    if (episodes.isEmpty) return null;

    return UnifiedSource(
      id: _sourceId(id),
      providerId: 'animevost',
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'animevost',
      subtitle: 'animevost',
      episodeCount: episodes.length,
      episodes: episodes,
      hasDirectStreams: true,
    );
  }

  Future<dynamic> _post(
    String path,
    Map<String, String> data,
  ) async {
    try {
      final response = await _dio.post<String>(
        path,
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final body = response.data ?? '';
      final trimmed = body.trimLeft();
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
      return jsonDecode(body);
    } catch (_) {
      // Ignore and return null.
    }
    return null;
  }

  static String? _absolute(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    return null;
  }

  static String _sourceId(int id) => 'animevost::$id';

  static int? _parseSourceId(String sourceId) {
    final parts = sourceId.split('::');
    if (parts.length < 2) return null;
    return int.tryParse(parts[1]);
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
    return left.split(' ').toSet().intersection(right.split(' ').toSet()).length *
        10;
  }
}
