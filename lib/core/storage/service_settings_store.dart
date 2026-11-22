// Persists which metadata/source providers are enabled.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which metadata/source providers are enabled.
///
/// Notifies listeners when toggles change so the UI can react.
class ServiceSettingsStore extends ChangeNotifier {
  ServiceSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _metadataKey = 'enabled_metadata_providers';
  static const _sourcesKey = 'enabled_source_providers';

  /// Default enabled providers (all by default).
  static const defaultMetadata = <String>{
    'shikimori',
  };
  static const defaultSources = <String>{
    'anilibria',
    'animevost',
    'anidub',
    'yani',
    'sameband',
    'yummyanime',
    'anilibme',
  };

  /// Get enabled metadata provider IDs.
  Set<String> getEnabledMetadata() {
    final list = _prefs.getStringList(_metadataKey);
    if (list == null) return defaultMetadata;
    return list.toSet();
  }

  /// Get enabled source provider IDs.
  Set<String> getEnabledSources() {
    final list = _prefs.getStringList(_sourcesKey);
    if (list == null) return defaultSources;
    return list.toSet();
  }

  /// Set enabled metadata provider IDs.
  Future<void> setEnabledMetadata(Set<String> ids) async {
    await _prefs.setStringList(_metadataKey, ids.toList());
    notifyListeners();
  }

  /// Set enabled source provider IDs.
  Future<void> setEnabledSources(Set<String> ids) async {
    await _prefs.setStringList(_sourcesKey, ids.toList());
    notifyListeners();
  }

  /// Toggle a metadata provider.
  Future<void> toggleMetadata(String id, bool enabled) async {
    final current = getEnabledMetadata();
    if (enabled) {
      current.add(id);
    } else {
      current.remove(id);
    }
    await setEnabledMetadata(current);
  }

  /// Toggle a source provider.
  Future<void> toggleSource(String id, bool enabled) async {
    final current = getEnabledSources();
    if (enabled) {
      current.add(id);
    } else {
      current.remove(id);
    }
    await setEnabledSources(current);
  }

  /// Reset to defaults.
  Future<void> reset() async {
    await _prefs.remove(_metadataKey);
    await _prefs.remove(_sourcesKey);
    notifyListeners();
  }
}
