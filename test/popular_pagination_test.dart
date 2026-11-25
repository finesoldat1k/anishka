import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/api/metadata/shikimori.dart';
import 'package:anishka/core/api/service_registry.dart';
import 'package:anishka/core/cache/unified_cache.dart';
import 'package:anishka/core/repository/unified_repository.dart';

void main() {
  group('popular pagination', () {
    test(
      'repository requests each page once and caches it separately',
      () async {
        final adapter = _PagingAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://shikimori.one/api'))
          ..httpClientAdapter = adapter;
        final repository = UnifiedRepository(
          registry: ApiServiceRegistry(
            metadata: MetadataProviderRegistry.create(
              providers: [Shikimori(dio: dio)],
              enabledIds: {'shikimori'},
            ),
            sources: SourceProviderRegistry.create(
              providers: const [],
              enabledIds: const {},
            ),
          ),
          cache: UnifiedCache(),
        );

        final first = await repository.getPopular(
          limit: 2,
          page: 1,
          status: 'ongoing',
        );
        final second = await repository.getPopular(
          limit: 2,
          page: 2,
          status: 'ongoing',
        );

        expect(first.single.id, 101);
        expect(second.single.id, 202);
        expect(adapter.pages, [1, 2]);

        // Page one is served from the cache; no extra network request.
        await repository.getPopular(limit: 2, page: 1, status: 'ongoing');
        expect(adapter.pages, [1, 2]);
      },
    );

    test('cache keys distinguish pages', () {
      expect(
        CacheKeys.shikimoriPopular('popularity', 'ongoing', null, 30, 1),
        isNot(CacheKeys.shikimoriPopular('popularity', 'ongoing', null, 30, 2)),
      );
    });
  });
}

class _PagingAdapter implements HttpClientAdapter {
  final List<int> pages = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = options.queryParameters['page'] as int? ?? 1;
    pages.add(page);
    final id = page * 100 + page;
    return ResponseBody.fromString(
      jsonEncode([
        {
          'id': id,
          'name': 'anime $page',
          'russian': 'аниме $page',
          'kind': 'tv',
          'score': '8.0',
          'status': 'ongoing',
          'episodes': 12,
          'episodes_aired': 1,
          'image': <String, dynamic>{},
          'url': '/animes/$id',
        },
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
