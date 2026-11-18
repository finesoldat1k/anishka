// Unified anime source for playback - combines Shikimori metadata with source-specific releases.
import 'anime_release.dart';
import 'anime_episode.dart';
import 'shikimori_anime.dart';
import 'voiceover.dart';

/// Represents a playable source (e.g., AniLibria release with specific voiceover).
class AnimeSource {
  const AnimeSource({
    required this.id,
    required this.shikimoriAnime,
    required this.release,
    required this.voiceover,
    required this.sourceType,
  });

  /// Unique identifier: "anilibria:{releaseId}:{voiceoverId}"
  final String id;

  /// Shikimori anime metadata (title, poster, description, etc.)
  final ShikimoriAnimeDetails shikimoriAnime;

  /// The AniLibria release (contains episodes with HLS URLs)
  final AnimeRelease release;

  /// Selected voiceover/dub from this release
  final VoiceoverInfo voiceover;

  /// Source type: 'anilibria', 'animevost', etc.
  final String sourceType;

  /// Display name for UI: "anilibria • aniдub"
  String get displayName => '$sourceType • ${voiceover.title}';

  /// Short label: "анидуб", "анилибрия", etc.
  String get shortLabel => voiceover.title;

  /// Voice cast label for display in UI
  String get voiceCastLabel => voiceover.subtitle;

  /// All episodes from this release with this voiceover
  List<AnimeEpisode> get episodes => release.episodes;

  /// Find episode by ordinal
  AnimeEpisode? episodeByOrdinal(int ordinal) => release.episodeByOrdinal(ordinal);

  /// Get HLS URL for episode at quality
  String? hlsForEpisode(int ordinal, String quality) {
    final ep = episodeByOrdinal(ordinal);
    return ep?.hlsForQuality(quality);
  }

  /// Available qualities for this source
  List<String> get availableQualities {
    final qualities = <String>{};
    for (final ep in episodes) {
      if (ep.hls1080 != null) qualities.add('1080');
      if (ep.hls720 != null) qualities.add('720');
      if (ep.hls480 != null) qualities.add('480');
    }
    return qualities.toList()..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
  }
}

/// Aggregated anime with all available sources.
class AnimeWithSources {
  const AnimeWithSources({
    required this.shikimoriAnime,
    required this.sources,
    this.related = const [],
  });

  final ShikimoriAnimeDetails shikimoriAnime;
  final List<AnimeSource> sources;
  final List<ShikimoriAnime> related;

  /// Primary display title from Shikimori
  String get displayTitle => shikimoriAnime.displayTitle;

  /// Poster from Shikimori
  String? get posterUrl => shikimoriAnime.posterUrl;

  /// Background from Shikimori
  String? get backgroundUrl => shikimoriAnime.backgroundUrl;

  /// All unique voiceovers across sources
  List<VoiceoverInfo> get allVoiceovers =>
      sources.map((s) => s.voiceover).toSet().toList();

  /// Check if any source has episodes
  bool get hasEpisodes => sources.any((s) => s.episodes.isNotEmpty);

  /// Default source (first available)
  AnimeSource? get defaultSource => sources.isNotEmpty ? sources.first : null;

  /// Get source by ID
  AnimeSource? sourceById(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }
}