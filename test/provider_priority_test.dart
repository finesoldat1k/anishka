import 'package:flutter_test/flutter_test.dart';
import 'package:anishka/core/api/metadata/metadata_provider.dart' hide MetadataProviderRegistry;
import 'package:anishka/core/api/metadata/unified_metadata.dart';
import 'package:anishka/core/api/service_registry.dart' show MetadataProviderRegistry, SourceProviderRegistry;
import 'package:anishka/core/api/sources/source_provider.dart';
import 'package:anishka/core/api/sources/unified_source.dart';

void main() {
  group('MetadataProviderRegistry priority tests', () {
    test('enabled providers are sorted by priority order', () {
      final providerA = _MockProvider('a');
      final providerB = _MockProvider('b');
      final providerC = _MockProvider('c');

      final registry = MetadataProviderRegistry.create(
        providers: [providerA, providerB, providerC],
        enabledIds: {'a', 'b', 'c'},
      );

      // Default priority order should be the order they were added
      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['a', 'b', 'c']);
    });

    test('reportSuccess moves provider to front', () {
      final providerA = _MockProvider('a');
      final providerB = _MockProvider('b');
      final providerC = _MockProvider('c');

      final registry = MetadataProviderRegistry.create(
        providers: [providerA, providerB, providerC],
        enabledIds: {'a', 'b', 'c'},
      );

      // Report success for 'c' - should move to front
      registry.reportSuccess('c');

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['c', 'a', 'b']);
    });

    test('reportFailure moves provider to back', () {
      final providerA = _MockProvider('a');
      final providerB = _MockProvider('b');
      final providerC = _MockProvider('c');

      final registry = MetadataProviderRegistry.create(
        providers: [providerA, providerB, providerC],
        enabledIds: {'a', 'b', 'c'},
      );

      // Report failure for 'a' - should move to back
      registry.reportFailure('a');

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['b', 'c', 'a']);
    });

    test('Shikimori is prioritized first by default', () {
      final shikimori = _MockProvider('shikimori');
      final anilist = _MockProvider('anilist');
      final jikan = _MockProvider('jikan');

      final registry = MetadataProviderRegistry.create(
        providers: [anilist, jikan, shikimori],
        enabledIds: {'shikimori', 'anilist', 'jikan'},
      );

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled.first, 'shikimori');
    });

    test('disabled providers are not in enabled list', () {
      final providerA = _MockProvider('a');
      final providerB = _MockProvider('b');

      final registry = MetadataProviderRegistry.create(
        providers: [providerA, providerB],
        enabledIds: {'a'},
      );

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['a']);
      expect(registry.isEnabled('b'), isFalse);
    });

    test('reorder changes priority order', () {
      final providerA = _MockProvider('a');
      final providerB = _MockProvider('b');
      final providerC = _MockProvider('c');

      final registry = MetadataProviderRegistry.create(
        providers: [providerA, providerB, providerC],
        enabledIds: {'a', 'b', 'c'},
      );

      // Reorder: move 'c' (index 2) to index 0
      registry.reorder(2, 0);

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['c', 'a', 'b']);
    });

    test('reorder move to end', () {
      final providerA = _MockProvider('a');
      final providerB = _MockProvider('b');
      final providerC = _MockProvider('c');

      final registry = MetadataProviderRegistry.create(
        providers: [providerA, providerB, providerC],
        enabledIds: {'a', 'b', 'c'},
      );

      // Reorder: move 'a' (index 0) to index 2
      registry.reorder(0, 2);

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['b', 'c', 'a']);
    });
  });

  group('SourceProviderRegistry priority tests', () {
    test('reorder changes priority order', () {
      final sourceA = _MockSource('a');
      final sourceB = _MockSource('b');
      final sourceC = _MockSource('c');

      final registry = SourceProviderRegistry.create(
        providers: [sourceA, sourceB, sourceC],
        enabledIds: {'a', 'b', 'c'},
      );

      // Reorder: move 'c' (index 2) to index 0
      registry.reorder(2, 0);

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled, ['c', 'a', 'b']);
    });

    test('AniLibria is prioritized first by default', () {
      final anilibria = _MockSource('anilibria');
      final yani = _MockSource('yani');
      final animevost = _MockSource('animevost');

      final registry = SourceProviderRegistry.create(
        providers: [yani, animevost, anilibria],
        enabledIds: {'anilibria', 'yani', 'animevost'},
      );

      final enabled = registry.enabled.map((p) => p.id).toList();
      expect(enabled.first, 'anilibria');
    });
  });
}

class _MockProvider implements MetadataProvider {
  _MockProvider(this._id);

  final String _id;

  @override
  String get displayName => _id;

  @override
  String get id => _id;

  @override
  Future<List<UnifiedMetadata>> search({required String query, int limit = 50}) async => [];

  @override
  Future<UnifiedMetadata?> getDetails(int shikimoriId) async => null;

  @override
  Future<List<String>> getScreenshots(int shikimoriId) async => [];

  @override
  Future<List<UnifiedMetadata>> getRelatedByFranchise(String franchise, {int limit = 30}) async => [];
}

class _MockSource implements SourceProvider {
  _MockSource(this._id);

  final String _id;

  @override
  String get displayName => _id;

  @override
  String get id => _id;

  @override
  Future<List<UnifiedSource>> findByShikimoriId(int shikimoriId, {String? nameHint}) async => [];

  @override
  Future<UnifiedSource?> getSource(String sourceId) async => null;

  @override
  Future<List<UnifiedSource>> search(String query) async => [];
}