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
    required this.createdAt,
  });

  final String value; // JSON-encoded string
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'value': value,
        'expiresAt': expiresAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  static PersistentCacheEntry fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.parse(json['expiresAt'] as String);
    return PersistentCacheEntry(
      value: json['value'] as String,
      expiresAt: expiresAt,
      // Entries written by older app versions have no createdAt; expiry is
      // the closest available approximation of their age.
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? expiresAt,
    );
  }
}

/// Persistent (disk) layer for API responses.
///
/// Keys are namespaced internally so they never collide with
/// `ServiceSettingsStore` or other `shared_preferences` entries.
class PersistentCache {
  PersistentCache(this._prefs, {this.maxEntries = 400});

  final SharedPreferences _prefs;

  /// Maximum number of entries kept on disk.
  final int maxEntries;

  static const String _prefix = 'anishka_cache:';

  String _key(String key) => '$_prefix$key';

  /// Read a cached value if present and not expired.
  T? read<T>(String key, T Function(dynamic json) decoder) {
    final entry = readEntry(key);
    if (entry == null) return null;
    try {
      return decoder(jsonDecode(entry.value));
    } catch (_) {
      return null;
    }
  }

  /// Read a raw cache entry (including its remaining TTL).
  PersistentCacheEntry? readEntry(String key) {
    final entry = _decode(_prefs.getString(_key(key)));
    if (entry == null || entry.isExpired) return null;
    return entry;
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
      createdAt: DateTime.now(),
    );
    await _prefs.setString(_key(key), jsonEncode(entry.toJson()));
    await _enforceSizeCap();
  }

  /// Write a pre-encoded JSON string with a TTL (no encoder type gymnastics).
  Future<void> writeRaw(String key, String jsonValue, Duration ttl) async {
    final now = DateTime.now();
    final entry = PersistentCacheEntry(
      value: jsonValue,
      expiresAt: now.add(ttl),
      createdAt: now,
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
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Count of cached entries.
  int get count {
    return _prefs.getKeys().where((k) => k.startsWith(_prefix)).length;
  }

  PersistentCacheEntry? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PersistentCacheEntry.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _enforceSizeCap() async {
    // `shared_preferences` does not expose sizes, so we cap by count and
    // evict the oldest entries (by creation time) first.
    final cap = maxEntries < 1 ? 1 : maxEntries;
    final storageKeys =
        _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    if (storageKeys.length <= cap) return;

    final alive = <({String key, DateTime createdAt})>[];
    for (final storageKey in storageKeys) {
      final entry = _decode(_prefs.getString(storageKey));
      if (entry == null || entry.isExpired) {
        await _prefs.remove(storageKey);
        continue;
      }
      alive.add((key: storageKey, createdAt: entry.createdAt));
    }

    final excess = alive.length - cap;
    if (excess <= 0) return;

    alive.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (var i = 0; i < excess; i++) {
      await _prefs.remove(alive[i].key);
    }
  }
}
