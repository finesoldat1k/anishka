import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime_card_item.dart';
import '../models/shikimori_anime.dart';

/// Storage for search history and recently visited anime.
class SearchStore extends ChangeNotifier {
  SearchStore(this._prefs) {
    _load();
  }

  static const _historyKey = 'anishka.search.history.v1';
  static const _visitedKey = 'anishka.search.visited.v1';
  static const _maxHistory = 20;
  static const _maxVisited = 20;

  final SharedPreferences _prefs;
  final List<String> _history = [];
  final List<VisitedAnime> _visited = [];

  List<String> get history => List.unmodifiable(_history);
  List<VisitedAnime> get visited => List.unmodifiable(_visited);

  void _load() {
    final rawHistory = _prefs.getString(_historyKey);
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHistory);
        if (decoded is List) {
          _history.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    final rawVisited = _prefs.getString(_visitedKey);
    if (rawVisited != null && rawVisited.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawVisited);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final visited = VisitedAnime.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              );
              if (visited != null) _visited.add(visited);
            }
          }
        }
      } catch (_) {}
    }
  }

  void addToHistory(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _history.removeWhere((h) => h.toLowerCase() == trimmed.toLowerCase());
    _history.insert(0, trimmed);
    if (_history.length > _maxHistory) _history.removeLast();
    persistHistory();
    notifyListeners();
  }

  void addVisited(dynamic anime) {
    final adapter = AnimeCardAdapter(anime);
    final item = VisitedAnime(
      id: adapter.id,
      title: adapter.displayTitle,
      posterUrl: adapter.posterUrl,
      year: adapter.year,
      score: adapter.score,
      episodeCount: adapter.episodeCount,
      isShikimori: anime is ShikimoriAnime || anime is ShikimoriAnimeDetails,
      visitedAt: DateTime.now(),
    );
    _visited.removeWhere((v) => v.id == item.id);
    _visited.insert(0, item);
    if (_visited.length > _maxVisited) _visited.removeLast();
    persistVisited();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    persistHistory();
    notifyListeners();
  }

  void clearVisited() {
    _visited.clear();
    persistVisited();
    notifyListeners();
  }

  void clearAll() {
    _history.clear();
    _visited.clear();
    persistHistory();
    persistVisited();
    notifyListeners();
  }

  void persistHistory() {
    unawaited(_prefs.setString(_historyKey, jsonEncode(_history)));
  }

  void persistVisited() {
    unawaited(_prefs.setString(
      _visitedKey,
      jsonEncode(_visited.map((v) => v.toJson()).toList()),
    ));
  }
}

class VisitedAnime {
  const VisitedAnime({
    required this.id,
    required this.title,
    required this.posterUrl,
    this.year,
    this.score,
    this.episodeCount,
    this.isShikimori = false,
    required this.visitedAt,
  });

  final int id;
  final String title;
  final String? posterUrl;
  final int? year;
  final double? score;
  final int? episodeCount;
  final bool isShikimori;
  final DateTime visitedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'poster_url': posterUrl,
    'year': year,
    'score': score,
    'episode_count': episodeCount,
    'is_shikimori': isShikimori,
    'visited_at': visitedAt.toIso8601String(),
  };

  static VisitedAnime? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int || id <= 0) return null;
    return VisitedAnime(
      id: id,
      title: (json['title'] as String?) ?? '',
      posterUrl: json['poster_url'] as String?,
      year: json['year'] as int?,
      score: (json['score'] as num?)?.toDouble(),
      episodeCount: json['episode_count'] as int?,
      isShikimori: json['is_shikimori'] as bool? ?? false,
      visitedAt: DateTime.tryParse(json['visited_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}