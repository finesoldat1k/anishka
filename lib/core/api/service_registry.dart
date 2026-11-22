// Core API service registry and provider interfaces.
export 'metadata/metadata_provider.dart';
export 'metadata/unified_metadata.dart';
export 'sources/source_provider.dart';
export 'sources/unified_source.dart';

import 'metadata/metadata_provider.dart';
import 'sources/source_provider.dart';

/// Unified registry for all API services (metadata + sources).
class ApiServiceRegistry {
  ApiServiceRegistry({required this.metadata, required this.sources});

  final MetadataProviderRegistry metadata;
  final SourceProviderRegistry sources;

  /// All metadata providers (enabled + disabled).
  List<MetadataProvider> get allMetadata => metadata.all;

  /// All source providers (enabled + disabled).
  List<SourceProvider> get allSources => sources.all;

  /// Currently enabled metadata providers.
  List<MetadataProvider> get enabledMetadata => metadata.enabled;

  /// Currently enabled source providers.
  List<SourceProvider> get enabledSources => sources.enabled;

  /// Check if a metadata provider is enabled.
  bool isMetadataEnabled(String id) => metadata.isEnabled(id);

  /// Check if a source provider is enabled.
  bool isSourceEnabled(String id) => sources.isEnabled(id);

  /// Enable/disable metadata provider.
  void setMetadataEnabled(String id, bool enabled) {
    if (enabled) {
      metadata.enable(id);
    } else {
      metadata.disable(id);
    }
  }

  /// Enable/disable source provider.
  void setSourceEnabled(String id, bool enabled) {
    if (enabled) {
      sources.enable(id);
    } else {
      sources.disable(id);
    }
  }

  /// Get metadata provider by ID.
  MetadataProvider? getMetadataProvider(String id) => metadata.getById(id);

  /// Get source provider by ID.
  SourceProvider? getSourceProvider(String id) => sources.getById(id);

  /// Report successful provider usage - moves it to front for future calls.
  void reportMetadataSuccess(String providerId) {
    metadata.reportSuccess(providerId);
  }

  /// Report failed provider usage.
  void reportMetadataFailure(String providerId) {
    metadata.reportFailure(providerId);
  }

  /// Reorder metadata providers - move from oldIndex to newIndex.
  void reorderMetadata(int oldIndex, int newIndex) {
    metadata.reorder(oldIndex, newIndex);
  }

  /// Reorder source providers - move from oldIndex to newIndex.
  void reorderSources(int oldIndex, int newIndex) {
    sources.reorder(oldIndex, newIndex);
  }
}

/// Priority-aware metadata provider registry.
class MetadataProviderRegistry {
  MetadataProviderRegistry._(this._all, this._enabled, this._priorityOrder);

  final List<MetadataProvider> _all;
  final Set<String> _enabled;
  final List<String> _priorityOrder; // Ordered list of provider IDs by success priority

  /// All registered providers.
  List<MetadataProvider> get all => List.unmodifiable(_all);

  /// Currently enabled providers in priority order.
  List<MetadataProvider> get enabled {
    final enabledProviders = _all.where((p) => _enabled.contains(p.id)).toList();
    // Sort by priority order
    enabledProviders.sort((a, b) {
      final aIndex = _priorityOrder.indexOf(a.id);
      final bIndex = _priorityOrder.indexOf(b.id);
      if (aIndex == -1 && bIndex == -1) return 0;
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });
    return enabledProviders;
  }

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

  /// Report successful provider usage - moves it to front.
  void reportSuccess(String providerId) {
    if (!_enabled.contains(providerId)) return;
    _priorityOrder.remove(providerId);
    _priorityOrder.insert(0, providerId);
  }

  /// Report failed provider usage - moves it to back.
  void reportFailure(String providerId) {
    _priorityOrder.remove(providerId);
    _priorityOrder.add(providerId);
  }

  /// Reorder providers in priority list.
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
    // Default priority: Shikimori first, then others by order in list
    final priorityOrder = providers
        .where((p) => enabledIds.contains(p.id))
        .map((p) => p.id)
        .toList();
    // Ensure Shikimori is first if enabled
    if (enabledIds.contains('shikimori')) {
      priorityOrder.remove('shikimori');
      priorityOrder.insert(0, 'shikimori');
    }
    return MetadataProviderRegistry._(providers, Set<String>.from(enabledIds), priorityOrder);
  }
}
