import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/json_utils.dart';
import '../models/anime_release.dart';

enum CollectionStatus {
  planned('в планах'),
  watching('смотрю'),
  completed('просмотренно');

  const CollectionStatus(this.label);

  final String label;

  static CollectionStatus? fromStorage(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return null;
  }
}

class LibraryEntry {
  const LibraryEntry({
    required this.anime,
    required this.status,
    required this.favorite,
    required this.updatedAt,
  });

  final AnimeRelease anime;
  final CollectionStatus? status;
  final bool favorite;
  final DateTime updatedAt;

  LibraryEntry copyWith({
    AnimeRelease? anime,
    CollectionStatus? status,
    bool clearStatus = false,
    bool? favorite,
    DateTime? updatedAt,
  }) {
    return LibraryEntry(
      anime: anime ?? this.anime,
      status: clearStatus ? null : (status ?? this.status),
      favorite: favorite ?? this.favorite,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'anime': anime.toSnapshotJson(),
    'status': status?.name,
    'favorite': favorite,
    'updated_at': updatedAt.toIso8601String(),
  };

  static LibraryEntry? fromJson(Map<String, dynamic> json) {
    final animeJson = json['anime'];
    if (animeJson is! Map) return null;
    final anime = AnimeRelease.fromSnapshot(
      animeJson.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (anime.id == 0) return null;
    return LibraryEntry(
      anime: anime,
      status: CollectionStatus.fromStorage(json['status']),
      favorite: asBool(json['favorite']),
      updatedAt: asDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class WatchProgress {
  const WatchProgress({
    required this.episode,
    required this.voice,
    required this.updatedAt,
  });

  final int episode;
  final String voice;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'episode': episode,
    'voice': voice,
    'updated_at': updatedAt.toIso8601String(),
  };

  static WatchProgress? fromJson(Map<String, dynamic> json) {
    final episode = asInt(json['episode']);
    if (episode == null || episode < 1) return null;
    return WatchProgress(
      episode: episode,
      voice: asString(json['voice']) ?? 'anilibria',
      updatedAt: asDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class LibraryStore extends ChangeNotifier {
  LibraryStore(this._prefs) {
    _load();
  }

  static const _libraryKey = 'anishka.library.v1';
  static const _progressKey = 'anishka.progress.v1';

  final SharedPreferences _prefs;
  final Map<int, LibraryEntry> _entries = {};
  final Map<int, WatchProgress> _progress = {};

  void _load() {
    var migrated = false;
    final rawLibrary = _prefs.getString(_libraryKey);
    if (rawLibrary != null && rawLibrary.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLibrary);
        final list = decoded is List ? decoded : const [];
        for (final item in list) {
          if (item is! Map) continue;
          final entry = LibraryEntry.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (entry != null) {
            // Older versions stored temporary snapshots under a negative id.
            // Re-home them under the canonical Shikimori id so favourite and
            // status lookups never depend on whether sources have loaded.
            final key = entry.anime.libraryId;
            final existing = _entries[key];
            _entries[key] = existing == null
                ? entry
                : LibraryEntry(
                    anime:
                        entry.anime.episodes.isNotEmpty ||
                            existing.anime.episodes.isEmpty
                        ? entry.anime
                        : existing.anime,
                    status: entry.status ?? existing.status,
                    favorite: entry.favorite || existing.favorite,
                    updatedAt: entry.updatedAt.isAfter(existing.updatedAt)
                        ? entry.updatedAt
                        : existing.updatedAt,
                  );
            if (key != entry.anime.id) migrated = true;
          }
        }
      } catch (_) {
        // повреждённое локальное хранилище не должно ломать запуск.
      }
    }
    if (migrated) _persistLibrary();

    final rawProgress = _prefs.getString(_progressKey);
    if (rawProgress != null && rawProgress.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProgress);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final id = int.tryParse(key.toString());
            if (id == null || value is! Map) return;
            final progress = WatchProgress.fromJson(
              value.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (progress != null) _progress[id] = progress;
          });
        }
      } catch (_) {
        // см. выше.
      }
    }
  }

  List<LibraryEntry> get all {
    final entries = _entries.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  List<LibraryEntry> favorites() =>
      all.where((entry) => entry.favorite).toList();

  List<LibraryEntry> byStatus(CollectionStatus status) =>
      all.where((entry) => entry.status == status).toList();

  int countFavorites() =>
      _entries.values.where((entry) => entry.favorite).length;

  int countStatus(CollectionStatus status) =>
      _entries.values.where((entry) => entry.status == status).length;

  LibraryEntry? entryFor(int id) => _entries[id];

  CollectionStatus? statusOf(int id) => _entries[id]?.status;

  bool isFavorite(int id) => _entries[id]?.favorite ?? false;

  WatchProgress? progressFor(int id) => _progress[id];

  int? lastEpisodeFor(int id) => _progress[id]?.episode;

  String voiceFor(int id, {String fallback = 'anilibria'}) =>
      _progress[id]?.voice ?? fallback;

  void syncSnapshot(AnimeRelease anime) {
    final key = anime.libraryId;
    final current = _entries[key];
    if (current == null) return;
    _entries[key] = current.copyWith(anime: anime);
    _persistLibrary();
    notifyListeners();
  }

  void setStatus(AnimeRelease anime, CollectionStatus? status) {
    final key = anime.libraryId;
    final current = _entries[key];
    if (status == null) {
      if (current == null) return;
      if (!current.favorite) {
        _entries.remove(key);
      } else {
        _entries[key] = current.copyWith(
          anime: anime,
          clearStatus: true,
          updatedAt: DateTime.now(),
        );
      }
    } else {
      _entries[key] =
          (current ??
                  LibraryEntry(
                    anime: anime,
                    status: null,
                    favorite: false,
                    updatedAt: DateTime.now(),
                  ))
              .copyWith(
                anime: anime,
                status: status,
                updatedAt: DateTime.now(),
              );
    }
    _persistLibrary();
    notifyListeners();
  }

  void toggleFavorite(AnimeRelease anime) {
    final key = anime.libraryId;
    final current = _entries[key];
    if (current == null) {
      _entries[key] = LibraryEntry(
        anime: anime,
        status: null,
        favorite: true,
        updatedAt: DateTime.now(),
      );
    } else if (current.favorite) {
      if (current.status == null) {
        _entries.remove(key);
      } else {
        _entries[key] = current.copyWith(
          anime: anime,
          favorite: false,
          updatedAt: DateTime.now(),
        );
      }
    } else {
      _entries[key] = current.copyWith(
        anime: anime,
        favorite: true,
        updatedAt: DateTime.now(),
      );
    }
    _persistLibrary();
    notifyListeners();
  }

  /// Migrate a legacy temporary Shikimori-only entry (negative id) to the
  /// real playable release. New entries are already stored under the canonical
  /// id, so this is a no-op for them.
  void adoptEntry(int temporaryId, AnimeRelease release) {
    final temporary = _entries.remove(temporaryId);
    if (temporary == null) return;
    final key = release.libraryId;
    final current = _entries[key];
    final favorite = temporary.favorite || (current?.favorite ?? false);
    final status = current?.status ?? temporary.status;
    if (status != null || favorite) {
      _entries[key] = LibraryEntry(
        anime: release,
        status: status,
        favorite: favorite,
        updatedAt: DateTime.now(),
      );
    }
    _persistLibrary();
    notifyListeners();
  }

  void saveProgress({
    required int releaseId,
    required int episode,
    required String voice,
  }) {
    final current = _progress[releaseId];
    if (current != null &&
        current.episode == episode &&
        current.voice == voice) {
      return;
    }
    _progress[releaseId] = WatchProgress(
      episode: episode,
      voice: voice,
      updatedAt: DateTime.now(),
    );
    _persistProgress();
    notifyListeners();
  }

  void _persistLibrary() {
    final data = _entries.values.map((entry) => entry.toJson()).toList();
    unawaited(_prefs.setString(_libraryKey, jsonEncode(data)));
  }

  void _persistProgress() {
    final data = _progress.map(
      (id, progress) => MapEntry(id.toString(), progress.toJson()),
    );
    unawaited(_prefs.setString(_progressKey, jsonEncode(data)));
  }
}
