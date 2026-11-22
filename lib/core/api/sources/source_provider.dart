// Core interfaces for video source providers (streaming, episodes, playback).
import 'unified_source.dart';

/// Common interface for all video source providers.
abstract interface class SourceProvider {
  /// Human-readable name for UI.
  String get displayName;

  /// Unique identifier for storage.
  String get id;

  /// Find sources by Shikimori ID.
  Future<List<UnifiedSource>> findByShikimoriId(
    int shikimoriId, {
    String? nameHint,
  });

  /// Get full source details by provider's internal ID.
  Future<UnifiedSource?> getSource(String sourceId);

  /// Search sources by query.
  Future<List<UnifiedSource>> search(String query);
}

/// Registry to manage enabled/disabled source providers with priority ordering.
class SourceProviderRegistry {
  SourceProviderRegistry._(this._all, this._enabled, this._priorityOrder);

  final List<SourceProvider> _all;
  final Set<String> _enabled;
  final List<String> _priorityOrder; // Ordered list of provider IDs by priority

  /// All registered providers.
  List<SourceProvider> get all => List.unmodifiable(_all);

  /// Currently enabled providers in priority order.
  List<SourceProvider> get enabled {
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
  SourceProvider? getById(String id) => _all.cast<SourceProvider?>().firstWhere(
    (p) => p?.id == id,
    orElse: () => null,
  );

  /// Reorder providers in priority list.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _priorityOrder.length) return;
    if (newIndex < 0 || newIndex >= _priorityOrder.length) return;
    if (oldIndex == newIndex) return;

    final item = _priorityOrder.removeAt(oldIndex);
    _priorityOrder.insert(newIndex, item);
  }

  static SourceProviderRegistry create({
    required List<SourceProvider> providers,
    required Set<String> enabledIds,
  }) {
    // Default priority: AniLibria first, then others by order in list
    final priorityOrder = providers
        .where((p) => enabledIds.contains(p.id))
        .map((p) => p.id)
        .toList();
    // Ensure AniLibria is first if enabled
    if (enabledIds.contains('anilibria')) {
      priorityOrder.remove('anilibria');
      priorityOrder.insert(0, 'anilibria');
    }
    return SourceProviderRegistry._(providers, Set<String>.from(enabledIds), priorityOrder);
  }
}