import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/api/service_registry.dart';
import 'package:anishka/core/cache/unified_cache.dart';
import 'package:anishka/core/models/anime_source.dart';
import 'package:anishka/core/repository/unified_repository.dart';

void main() {
  group('UnifiedRepository detail flow', () {
    late _MockMetadata provider;
    late UnifiedRepository repository;

    setUp(() {
      provider = _MockMetadata(
        'yani',
        const UnifiedMetadata(
          id: 777,
          shikimoriId: 0,
          title: 'Test Anime',
          englishTitle: 'Test Anime',
          description: 'description',
          year: 2024,
          genres: ['action'],
        ),
      );
      repository = UnifiedRepository(
        registry: ApiServiceRegistry(
          metadata: MetadataProviderRegistry.create(
            providers: [provider],
            enabledIds: {'yani'},
          ),
          sources: SourceProviderRegistry.create(
            providers: const [],
            enabledIds: const {},
          ),
        ),
        cache: UnifiedCache(),
      );
    });

    test('uses the canonical route id and emits a partial result', () async {
      final partials = <AnimeWithSources>[];

      final full = await repository.getAnimeWithSources(
        42,
        titleHint: 'Test Anime',
        onPartial: partials.add,
      );

      expect(full.shikimoriAnime.id, 42);
      expect(full.displayTitle, 'Test Anime');
      expect(full.shikimoriAnime.metadataYear, 2024);
      expect(full.sources, isEmpty);
      expect(partials, hasLength(1));
      expect(partials.single.shikimoriAnime.id, 42);
      expect(partials.single.sources, isEmpty);
    });

    test('serves repeated loads from cache and refreshes on demand', () async {
      await repository.getAnimeWithSources(42, titleHint: 'Test Anime');
      expect(provider.searchCalls, 1);
      expect(provider.detailsCalls, 1);
      expect(provider.screenshotCalls, 1);

      await repository.getAnimeWithSources(42, titleHint: 'Test Anime');
      expect(provider.searchCalls, 1);
      expect(provider.detailsCalls, 1);
      expect(provider.screenshotCalls, 1);

      await repository.getAnimeWithSources(
        42,
        titleHint: 'Test Anime',
        refresh: true,
      );
      expect(provider.searchCalls, 2);
      expect(provider.detailsCalls, 2);
      expect(provider.screenshotCalls, 2);
    });

    test('expands a lightweight source before dropping it', () async {
      final lazy = _LazySource();
      final lazyRepository = UnifiedRepository(
        registry: ApiServiceRegistry(
          metadata: MetadataProviderRegistry.create(
            providers: [provider],
            enabledIds: {'yani'},
          ),
          sources: SourceProviderRegistry.create(
            providers: [lazy],
            enabledIds: {'lazy'},
          ),
        ),
        cache: UnifiedCache(),
      );

      final full = await lazyRepository.getAnimeWithSources(
        42,
        titleHint: 'Test Anime',
      );

      expect(full.sources, hasLength(1));
      expect(full.sources.single.sourceType, 'lazy');
      expect(full.sources.single.episodes, hasLength(2));
      expect(lazy.getSourceCalls, 1);
    });

    test('orders sources by the registry priority', () async {
      final beta = _MockSource('beta');
      final alpha = _MockSource('alpha');
      final sources = SourceProviderRegistry.create(
        providers: [beta, alpha],
        enabledIds: {'beta', 'alpha'},
      );
      // Move alpha in front of beta, as the settings screen would.
      sources.reorder(1, 0);

      final orderedRepository = UnifiedRepository(
        registry: ApiServiceRegistry(
          metadata: MetadataProviderRegistry.create(
            providers: [provider],
            enabledIds: {'yani'},
          ),
          sources: sources,
        ),
        cache: UnifiedCache(),
      );

      final full = await orderedRepository.getAnimeWithSources(
        42,
        titleHint: 'Test Anime',
      );

      expect(
        full.sources.map((source) => source.sourceType),
        ['alpha', 'beta'],
      );
    });
  });
}

class _MockMetadata implements MetadataProvider {
  _MockMetadata(this.id, this.metadata);

  @override
  final String id;

  final UnifiedMetadata metadata;

  int searchCalls = 0;
  int detailsCalls = 0;
  int screenshotCalls = 0;

  @override
  String get displayName => id;

  @override
  Future<List<UnifiedMetadata>> search({
    required String query,
    int limit = 50,
  }) async {
    searchCalls++;
    return [metadata];
  }

  @override
  Future<UnifiedMetadata?> getDetails(int shikimoriId) async {
    detailsCalls++;
    return metadata;
  }

  @override
  Future<List<String>> getScreenshots(int shikimoriId) async {
    screenshotCalls++;
    return const [];
  }

  @override
  Future<List<UnifiedMetadata>> getRelatedByFranchise(
    String franchise, {
    int limit = 30,
  }) async {
    return const [];
  }
}

class _LazySource implements SourceProvider {
  int getSourceCalls = 0;

  @override
  String get id => 'lazy';

  @override
  String get displayName => 'lazy';

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    return [
      UnifiedSource(
        id: 'lazy:$shikimoriId',
        providerId: id,
        title: 'lazy',
        episodeCount: 0,
      ),
    ];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async {
    getSourceCalls++;
    return UnifiedSource(
      id: sourceId,
      providerId: id,
      title: 'lazy',
      episodeCount: 2,
      episodes: const [
        UnifiedEpisode(id: 'lazy-1', ordinal: 1, title: '1'),
        UnifiedEpisode(id: 'lazy-2', ordinal: 2, title: '2'),
      ],
    );
  }

  @override
  Future<List<UnifiedSource>> search(String query) async => const [];
}

class _MockSource implements SourceProvider {
  _MockSource(this.id);

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  }) async {
    return [
      UnifiedSource(
        id: '$id:$shikimoriId',
        providerId: id,
        title: id,
        episodeCount: 1,
        hasDirectStreams: true,
        episodes: [
          UnifiedEpisode(
            id: '$id-1',
            ordinal: 1,
            title: '1',
            hls720: 'https://example/$id.m3u8',
          ),
        ],
      ),
    ];
  }

  @override
  Future<UnifiedSource?> getSource(String sourceId) async => null;

  @override
  Future<List<UnifiedSource>> search(String query) async => const [];
}
