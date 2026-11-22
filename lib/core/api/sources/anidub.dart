import 'dart:async';

import 'package:dio/dio.dart';

import 'source_provider.dart';
import 'unified_source.dart';

/// AniDub source provider — scrapes anidub.com for episodes and voiceovers.
/// Currently a placeholder using Yani internally for unified access.
class AniDub implements SourceProvider {
  AniDub({Dio? dio})
      : _dio =
            dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://anidub.com',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'text/html,application/xhtml+xml',
                  'User-Agent': 'anishka/1.0',
                },
              ),
            );

  final Dio _dio;

  @override
  String get displayName => 'anidub';

  @override
  String get id => 'anidub';

  @override
  Future<List<UnifiedSource>> search(String query) async {
    // TODO: Implement direct search on anidub.com
    return const [];
  }

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    // TODO: Implement direct search by Shikimori ID
    return const [];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    // TODO: Implement release details
    return null;
  }
}