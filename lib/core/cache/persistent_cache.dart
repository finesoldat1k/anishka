// Disk-backed cache for API responses (offline-first).
//
// JSON payloads are persisted to `shared_preferences` with a TTL so the app
// can serve catalog/search/details data without network, and revalidate in
// the background when a connection is available.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single cached API response.
class PersistentCacheEntry {
  const PersistentCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final String value; // JSON-encoded string
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'value': value,
        'expiresAt': expiresAt.toIso8601String(),
      };

  static PersistentCacheEntry fromJson(Map<String, dynamic> json) {
    return PersistentCacheEntry(
      value: json['value'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

/// Persistent (disk) layer for API responses.
///
/// Keys are namespaced internally so they never collide with
/// `ServiceSettingsStore` or other `shared_preferences` entries.
class PersistentCache {
  PersistentCache(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'anishka_cache:';
  static const int _maxSizeBytes = 5 * 1024 * 1024; // ~5 MB cap

  String _key(String key) => '$_prefix$key';

  /// Read a cached value if present and not expired.
  T? read<T>(String key, T Function(dynamic json) decoder) {
    final raw = _prefs.getString(_key(key));
    if (raw == null) return null;
    try {
      final entry = PersistentCacheEntry.fromJson(jsonDecode(raw));
      if (entry.isExpired) return null;
      return decoder(jsonDecode(entry.value));
    } catch (_) {
      return null;
    }
  }

  /// Write a value with a TTL.
  Future<void> write<T>(
    String key,
    T value,
    Duration ttl, {
    T Function(T)? encoder,
  }) async {
    final entry = PersistentCacheEntry(
      value: jsonEncode(encoder != null ? encoder(value) : value),
      expiresAt: DateTime.now().add(ttl),
    );
    await _prefs.setString(_key(key), jsonEncode(entry.toJson()));
    await _enforceSizeCap();
  }

  /// Write a pre-encoded JSON string with a TTL (no encoder type gymnastics).
  Future<void> writeRaw(String key, String jsonValue, Duration ttl) async {
    final entry = PersistentCacheEntry(
      value: jsonValue,
      expiresAt: DateTime.now().add(ttl),
    );
    await _prefs.setString(_key(key), jsonEncode(entry.toJson()));
    await _enforceSizeCap();
  }

  /// Remove a single key.
  Future<void> remove(String key) async {
    await _prefs.remove(_key(key));
  }

  /// Remove all keys matching a predicate.
  Future<void> removeWhere(bool Function(String key) predicate) async {
    final keys = _prefs.getKeys().where((k) {
      if (!k.startsWith(_prefix)) return false;
      return predicate(k.substring(_prefix.length));
    }).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Clear every anishka cache entry.
  Future<void> clear() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Count of cached entries.
  int get count {
    return _prefs.getKeys().where((k) => k.startsWith(_prefix)).length;
  }

  Future<void> _enforceSizeCap() async {
    // Best-effort: if we exceed the cap, drop the oldest half of entries.
    // `shared_preferences` does not expose sizes, so we cap by count instead.
    const int maxEntries = 400;
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    if (keys.length <= maxEntries) return;
    keys.sort();
    final toRemove = keys.sublist(0, keys.length - maxEntries);
    for (final key in toRemove) {
      await _prefs.remove(key);
    }
  }
}
