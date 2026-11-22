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
  static const _sourcesVersionKey = 'enabled_source_providers_version';

  /// Bump when the set of source providers changes.
  static const _sourcesVersion = 2;

  /// Providers that no longer exist; dropped from saved settings on upgrade.
  static const _removedSources = <String>{'anidub', 'yummyanime'};

  /// Providers added after v1; enabled for existing users on upgrade.
  static const _addedSources = <String>{'kodik', 'hdrezka'};

  /// Default enabled providers (all by default).
  static const defaultMetadata = <String>{
    'shikimori',
  };
  static const defaultSources = <String>{
    'anilibria',
    'yani',
    'kodik',
    'hdrezka',
    'animevost',
    'sameband',
    'anilibme',
  };

  /// Get enabled metadata provider IDs.
  Set<String> getEnabledMetadata() {
    final list = _prefs.getStringList(_metadataKey);
    if (list == null) return defaultMetadata;
    return list.toSet();
  }

  /// Get enabled source provider IDs.
  ///
  /// Saved settings are migrated in place when the provider set changes:
  /// removed providers are dropped and new ones are enabled.
  Set<String> getEnabledSources() {
    final list = _prefs.getStringList(_sourcesKey);
    if (list == null) return defaultSources;

    final current = list.toSet();
    final version = _prefs.getInt(_sourcesVersionKey) ?? 1;
    if (version >= _sourcesVersion) return current;

    current.removeAll(_removedSources);
    // Do not resurrect providers for users who disabled everything.
    if (current.isNotEmpty) current.addAll(_addedSources);

    _prefs.setStringList(_sourcesKey, current.toList());
    _prefs.setInt(_sourcesVersionKey, _sourcesVersion);
    return current;
  }

  /// Set enabled metadata provider IDs.
  Future<void> setEnabledMetadata(Set<String> ids) async {
    await _prefs.setStringList(_metadataKey, ids.toList());
    notifyListeners();
  }

  /// Set enabled source provider IDs.
  Future<void> setEnabledSources(Set<String> ids) async {
    await _prefs.setStringList(_sourcesKey, ids.toList());
    await _prefs.setInt(_sourcesVersionKey, _sourcesVersion);
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
    await _prefs.remove(_sourcesVersionKey);
    notifyListeners();
  }
}
