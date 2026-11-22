// Core interfaces for metadata providers (catalog, search, details, images).
import 'unified_metadata.dart';

/// Common interface for all metadata providers.
abstract interface class MetadataProvider {
  /// Human-readable name for UI.
  String get displayName;

  /// Unique identifier for storage.
  String get id;

  /// Search anime by query. Returns unified metadata.
  Future<List<UnifiedMetadata>> search({
    required String query,
    int limit = 50,
  });

  /// Get full anime details by Shikimori ID.
  Future<UnifiedMetadata?> getDetails(int shikimoriId);

  /// Get episode stills (screenshots).
  Future<List<String>> getScreenshots(int shikimoriId);

  /// Get related anime by franchise.
  Future<List<UnifiedMetadata>> getRelatedByFranchise(
    String franchise, {
    int limit = 30,
  });
}

/// Registry to manage enabled/disabled metadata providers.
class MetadataProviderRegistry {
  MetadataProviderRegistry._(this._all, this._enabled);

  final List<MetadataProvider> _all;
  final Set<String> _enabled;

  /// All registered providers.
  List<MetadataProvider> get all => List.unmodifiable(_all);

  /// Currently enabled providers.
  List<MetadataProvider> get enabled =>
      _all.where((p) => _enabled.contains(p.id)).toList();

  /// Check if a provider is enabled.
  bool isEnabled(String id) => _enabled.contains(id);

  /// Enable a provider.
  void enable(String id) => _enabled.add(id);

  /// Disable a provider.
  void disable(String id) => _enabled.remove(id);

  /// Get provider by ID.
  MetadataProvider? getById(String id) => _all
      .cast<MetadataProvider?>()
      .firstWhere((p) => p?.id == id, orElse: () => null);

  static MetadataProviderRegistry create({
    required List<MetadataProvider> providers,
    required Set<String> enabledIds,
  }) {
    return MetadataProviderRegistry._(providers, Set<String>.from(enabledIds));
  }
}