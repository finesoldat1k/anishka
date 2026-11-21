// AniLibria video source implementation.
import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/api/anilibria_api.dart';
import '../../core/models/anime_release.dart';
import '../../core/models/video_source.dart';

class AniLibriaVideoSource implements VideoSource {
  AniLibriaVideoSource({AniLibriaApi? api, Dio? dio})
    : _api = api ?? AniLibriaApi(dio: dio);

  final AniLibriaApi _api;

  @override
  String get sourceId => 'anilibria';

  @override
  String get displayName => 'AniLibria';

  @override
  int get priority => 1; // Highest priority

  @override
  List<String> get availableQualities => const ['1080', '720', '480'];

  @override
  Future<bool> healthCheck() async {
    try {
      await _api.release(1); // Test with any release
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<SourceAnimeEntry>> search(String query, {int limit = 50}) async {
    final releases = await _api.search(query);
    return releases
        .take(limit)
        .map(
          (r) => SourceAnimeEntry(
            sourceId: sourceId,
            externalId: r.id.toString(),
            title: r.englishName ?? r.name,
            russianTitle: r.name,
            posterUrl: r.posterUrl,
            year: r.year,
            kind: r.type?.toLowerCase(),
            status: r.isOngoing
                ? 'ongoing'
                : (r.isInProduction ? 'anons' : 'released'),
            episodes: r.episodeCount,
            score: r.score?.toString(),
          ),
        )
        .toList();
  }

  @override
  Future<SourceAnimeDetails?> getDetails(String externalId) async {
    final id = int.tryParse(externalId);
    if (id == null) return null;

    try {
      final release = await _api.release(id);
      return _mapRelease(release);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SourceEpisode>> getEpisodes(String externalId) async {
    final id = int.tryParse(externalId);
    if (id == null) return const [];

    try {
      final release = await _api.release(id);
      return release.episodes
          .map(
            (e) => SourceEpisode(
              externalId: e.id,
              ordinal: e.ordinal,
              title: e.name,
              duration: e.duration?.inSeconds,
              posterUrl: e.previewUrl,
              hlsUrls: {
                if (e.hls1080 != null) '1080': e.hls1080!,
                if (e.hls720 != null) '720': e.hls720!,
                if (e.hls480 != null) '480': e.hls480!,
              },
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String?> getStreamUrl(String sourceEpisodeId, String quality) async {
    // For AniLibria, episodes are fetched with getEpisodes which includes HLS URLs
    // This method is kept for interface compatibility
    return null;
  }

  SourceAnimeDetails _mapRelease(AnimeRelease release) {
    return SourceAnimeDetails(
      sourceId: sourceId,
      externalId: release.id.toString(),
      title: release.englishName ?? release.name,
      russianTitle: release.name,
      description: release.description,
      posterUrl: release.posterUrl,
      backgroundUrl: release.backgroundUrl,
      year: release.year,
      kind: release.type?.toLowerCase(),
      status: release.isOngoing
          ? 'ongoing'
          : (release.isInProduction ? 'anons' : 'released'),
      episodes: release.episodeCount,
      score: release.score?.toString(),
      genres: release.genres,
      studios: release.voiceActors.map((v) => v.nickname).toList(),
      episodesList: release.episodes
          .map(
            (e) => SourceEpisode(
              externalId: e.id,
              ordinal: e.ordinal,
              title: e.name,
              duration: e.duration?.inSeconds,
              posterUrl: e.previewUrl,
              hlsUrls: {
                if (e.hls1080 != null) '1080': e.hls1080!,
                if (e.hls720 != null) '720': e.hls720!,
                if (e.hls480 != null) '480': e.hls480!,
              },
            ),
          )
          .toList(),
    );
  }
}
