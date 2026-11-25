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
