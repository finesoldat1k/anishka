// Core interfaces for metadata providers (catalog, search, details, images).
import '../service_info.dart';
import 'unified_metadata.dart';

/// Common interface for all metadata providers.
abstract interface class MetadataProvider implements ServiceInfo {
  /// Human-readable name for UI.
  @override
  String get displayName;

  /// Unique identifier for storage.
  @override
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

/// Registry to manage enabled/disabled metadata providers with priority
/// ordering.
///
/// The priority order is used by the repository to decide which provider to
/// query first. Successful providers move to the front, failing ones to the
/// back, and the order can be changed explicitly from the settings screen.
class MetadataProviderRegistry {
  MetadataProviderRegistry._(this._all, this._enabled, this._priorityOrder);

  final List<MetadataProvider> _all;
  final Set<String> _enabled;
  final List<String> _priorityOrder;

  /// All registered providers.
  List<MetadataProvider> get all => List.unmodifiable(_all);

  /// Currently enabled providers in priority order.
  List<MetadataProvider> get enabled {
    final enabledProviders =
        _all.where((p) => _enabled.contains(p.id)).toList();
    enabledProviders.sort((a, b) {
      final aIndex = _priorityIndex(a.id);
      final bIndex = _priorityIndex(b.id);
      if (aIndex == bIndex) return 0;
      return aIndex.compareTo(bIndex);
    });
    return enabledProviders;
  }

  int _priorityIndex(String id) {
    final index = _priorityOrder.indexOf(id);
    return index == -1 ? _priorityOrder.length : index;
  }

  /// Check if a provider is enabled.
  bool isEnabled(String id) => _enabled.contains(id);

  /// Enable a provider.
  void enable(String id) {
    _enabled.add(id);
    if (!_priorityOrder.contains(id)) _priorityOrder.add(id);
  }

  /// Disable a provider.
  void disable(String id) => _enabled.remove(id);

  /// Get provider by ID.
  MetadataProvider? getById(String id) {
    for (final provider in _all) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// Priority index of a provider (lower is better).
  int priorityOf(String id) => _priorityIndex(id);

  /// Report successful provider usage - moves it to front.
  void reportSuccess(String providerId) {
    if (!_enabled.contains(providerId)) return;
    _priorityOrder.remove(providerId);
    _priorityOrder.insert(0, providerId);
  }

  /// Report failed provider usage - moves it to back.
  void reportFailure(String providerId) {
    if (!_enabled.contains(providerId)) return;
    _priorityOrder.remove(providerId);
    _priorityOrder.add(providerId);
  }

  /// Reorder providers in the priority list.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _priorityOrder.length) return;
    if (newIndex < 0 || newIndex >= _priorityOrder.length) return;
    if (oldIndex == newIndex) return;

    final item = _priorityOrder.removeAt(oldIndex);
    _priorityOrder.insert(newIndex, item);
  }

  static MetadataProviderRegistry create({
    required List<MetadataProvider> providers,
    required Set<String> enabledIds,
  }) {
    final priorityOrder = providers
        .where((p) => enabledIds.contains(p.id))
        .map((p) => p.id)
        .toList();
    // Shikimori owns the canonical IDs used across the app.
    if (enabledIds.contains('shikimori')) {
      priorityOrder.remove('shikimori');
      priorityOrder.insert(0, 'shikimori');
    }
    return MetadataProviderRegistry._(
      List<MetadataProvider>.from(providers),
      Set<String>.from(enabledIds),
      priorityOrder,
    );
  }
}
