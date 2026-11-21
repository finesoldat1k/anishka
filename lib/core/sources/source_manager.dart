// Multi-source manager with fallback logic.
import 'dart:async';

import '../../core/models/video_source.dart';
import 'anilibria_source.dart';
import 'animevost_source.dart';
import 'anidub_source.dart';
import 'kodik_source.dart';

class VideoSourceManager {
  VideoSourceManager({
    AniLibriaVideoSource? anilibria,
    AnimeVostVideoSource? animevost,
    AniDubVideoSource? anidub,
    KodikVideoSource? kodik,
  }) : _sources = [
         anilibria ?? AniLibriaVideoSource(),
         animevost ?? AnimeVostVideoSource(),
         anidub ?? AniDubVideoSource(),
         ?kodik,
       ]..sort((a, b) => a.priority.compareTo(b.priority));

  final List<VideoSource> _sources;

  List<VideoSource> get sources => List.unmodifiable(_sources);

  /// Search across all sources, returns merged deduplicated results
  Future<List<SourceAnimeEntry>> search(String query, {int limit = 50}) async {
    final allResults = <SourceAnimeEntry>[];
    final seen = <String>{};

    // Search all sources in parallel
    final futures = _sources.map(
      (s) =>
          s.search(query, limit: limit).catchError((_) => <SourceAnimeEntry>[]),
    );
    final allLists = await Future.wait(futures);

    for (final list in allLists) {
      for (final entry in list) {
        final key = '${entry.sourceId}:${entry.externalId}';
        if (seen.add(key)) {
          allResults.add(entry);
        }
      }
    }

    return allResults.take(limit).toList();
  }

  /// Get details from first available source
  Future<SourceAnimeDetails?> getDetails(
    String sourceId,
    String externalId,
  ) async {
    final source = _sources.firstWhere(
      (s) => s.sourceId == sourceId,
      orElse: () => throw ArgumentError('Source not found: $sourceId'),
    );
    return source.getDetails(externalId);
  }

  /// Try to get details from any source by external ID (fallback chain)
  Future<SourceAnimeDetails?> getDetailsAny(
    String externalId, {
    String? preferredSource,
  }) async {
    final ordered = preferredSource != null
        ? [
            ..._sources.where((s) => s.sourceId == preferredSource),
            ..._sources.where((s) => s.sourceId != preferredSource),
          ]
        : _sources;

    for (final source in ordered) {
      try {
        final details = await source
            .getDetails(externalId)
            .timeout(const Duration(seconds: 10));
        if (details != null) return details;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Get episodes from first available source
  Future<List<SourceEpisode>> getEpisodes(
    String sourceId,
    String externalId,
  ) async {
    final source = _sources.firstWhere(
      (s) => s.sourceId == sourceId,
      orElse: () => throw ArgumentError('Source not found: $sourceId'),
    );
    return source.getEpisodes(externalId);
  }

  /// Try episodes from any source (fallback chain)
  Future<List<SourceEpisode>> getEpisodesAny(
    String externalId, {
    String? preferredSource,
  }) async {
    final ordered = preferredSource != null
        ? [
            ..._sources.where((s) => s.sourceId == preferredSource),
            ..._sources.where((s) => s.sourceId != preferredSource),
          ]
        : _sources;

    for (final source in ordered) {
      try {
        final episodes = await source
            .getEpisodes(externalId)
            .timeout(const Duration(seconds: 10));
        if (episodes.isNotEmpty) return episodes;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  /// Resolve a stream URL using one exact source (no cross-source fallback).
  ///
  /// Scraped sources carry lazy resolver ids, so the source is always known.
  Future<String?> streamUrl(
    String sourceId,
    String sourceEpisodeId, {
    String quality = 'auto',
  }) async {
    final source = _sources.firstWhere(
      (s) => s.sourceId == sourceId,
      orElse: () => throw ArgumentError('Source not found: $sourceId'),
    );
    return source.getStreamUrl(sourceEpisodeId, quality);
  }

  /// Get stream URL with fallback across sources
  Future<String?> getStreamUrl(
    String sourceEpisodeId,
    String quality, {
    String? preferredSource,
  }) async {
    final ordered = preferredSource != null
        ? [
            ..._sources.where((s) => s.sourceId == preferredSource),
            ..._sources.where((s) => s.sourceId != preferredSource),
          ]
        : _sources;

    for (final source in ordered) {
      try {
        final url = await source
            .getStreamUrl(sourceEpisodeId, quality)
            .timeout(const Duration(seconds: 10));
        if (url != null && url.isNotEmpty) return url;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Check health of all sources
  Future<Map<String, bool>> healthCheckAll() async {
    final results = <String, bool>{};
    for (final source in _sources) {
      try {
        results[source.sourceId] = await source.healthCheck().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {
        results[source.sourceId] = false;
      }
    }
    return results;
  }

  /// Get available sources
  List<VideoSource> getAvailableSources() =>
      _sources.where((s) => _sources.contains(s)).toList();
}
