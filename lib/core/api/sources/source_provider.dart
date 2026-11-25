// Core interfaces for video source providers (streaming, episodes, playback).
import '../service_info.dart';
import 'resolved_stream.dart';
import 'unified_source.dart';

/// Common interface for all video source providers.
abstract interface class SourceProvider implements ServiceInfo {
  /// Human-readable name for UI.
  @override
  String get displayName;

  /// Unique identifier for storage.
  @override
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

/// Optional capability for providers that resolve streams lazily.
///
/// Implemented by scraped sources (HDRezka, Kodik, ...) where episode URLs are
/// signed and only valid for a short time. [sourceId] is the provider-specific
/// resolver payload stored on the episode, not the source id.
abstract interface class StreamResolvableSourceProvider {
  Future<ResolvedStream?> resolveStream(
    String sourceId, {
    int? ordinal,
    String quality = 'auto',
  });
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
  SourceProvider? getById(String id) {
    for (final provider in _all) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  /// Priority index of a provider (lower is better).
  int priorityOf(String id) => _priorityIndex(id);

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
