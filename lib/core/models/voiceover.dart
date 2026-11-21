// Common interface for voiceover/dub information across all sources.
import 'anime_release.dart';

/// Base interface for voiceover/dub information.
abstract class VoiceoverInfo {
  /// Unique identifier for this voiceover
  String get id;

  /// Display title (e.g., "AniDub", "AnimeVost", "Anilibria")
  String get title;

  /// Subtitle/description (e.g., "AniDub · Studio Name")
  String get subtitle;

  /// Source identifier (e.g., "anilibria", "animevost", "anidub")
  String get source;

  /// Optional studio/source logo.
  String? get logoUrl => null;

  /// People or teams credited for this track.
  List<String> get participants => const [];

  /// Number of episodes available for this voiceover, when known.
  int get episodeCount => 0;
}

/// AniLibria voiceover: one studio track for a release, with the cast names
/// kept as secondary information (not as the voiceover title).
class AniLibriaVoiceover implements VoiceoverInfo {
  const AniLibriaVoiceover({
    required this.releaseId,
    required this.members,
    this.episodes = 0,
  });

  final int releaseId;
  final List<ReleaseMember> members;
  final int episodes;

  @override
  String get id => 'anilibria_$releaseId';

  @override
  String get title => 'anilibria';

  @override
  String get subtitle {
    final names = participants;
    if (names.isEmpty) return 'озвучка студии anilibria';
    final shown = names.take(4).join(', ');
    final suffix = names.length > 4 ? ' и др.' : '';
    return 'озвучка студии · $shown$suffix';
  }

  @override
  String get source => 'anilibria';

  @override
  String? get logoUrl => 'https://anilibria.top/favicon.ico';

  @override
  List<String> get participants => members
      .map((member) => member.displayName.trim())
      .where((name) => name.isNotEmpty)
      .toList();

  @override
  int get episodeCount => episodes;

  /// Access to original ReleaseMember for AniLibria-specific data.
  ReleaseMember? get releaseMember => members.isEmpty ? null : members.first;
}

/// Generic voiceover for other sources (AnimeVost, AniDub, Kodik, etc.)
class GenericVoiceover implements VoiceoverInfo {
  const GenericVoiceover({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.source,
    this.logoUrl,
    this.participants = const [],
    this.episodeCount = 0,
  });

  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final String source;

  @override
  final String? logoUrl;

  @override
  final List<String> participants;

  @override
  final int episodeCount;
}

/// Legacy compatibility: AnimeVoiceover used by the in-player quick picker.
/// @deprecated Use VoiceoverInfo implementations instead.
@Deprecated(
  'Use VoiceoverInfo implementations (AniLibriaVoiceover, GenericVoiceover) instead',
)
class AnimeVoiceover implements VoiceoverInfo {
  const AnimeVoiceover({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.source,
    this.logoUrl,
    this.participants = const [],
    this.episodeCount = 0,
  });

  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final String source;

  @override
  final String? logoUrl;

  @override
  final List<String> participants;

  @override
  final int episodeCount;

  String get displayName => title;

  static AnimeVoiceover empty() =>
      const AnimeVoiceover(id: '', title: '', subtitle: '', source: '');
}

/// Legacy compatibility constants and functions.
@Deprecated('Use VoiceoverInfo implementations instead')
const String defaultVoiceoverId = 'anilibria';

/// Legacy compatibility function.
@Deprecated('Use VoiceoverInfo implementations instead')
List<AnimeVoiceover> voiceoversFor(AnimeRelease release) {
  final cast = release.voiceCastLabel;
  return [
    AnimeVoiceover(
      id: defaultVoiceoverId,
      title: 'anilibria',
      subtitle: cast == 'русская озвучка'
          ? 'озвучка студии'
          : 'озвучка студии · $cast',
      source: 'anilibria',
      logoUrl: 'https://anilibria.top/favicon.ico',
      participants: release.voiceActors
          .map((actor) => actor.displayName)
          .where((name) => name.isNotEmpty)
          .toList(),
      episodeCount: release.episodes.length,
    ),
  ];
}

/// Legacy compatibility function.
@Deprecated('Use VoiceoverInfo implementations instead')
AnimeVoiceover voiceoverById(AnimeRelease release, String? voiceId) {
  final all = voiceoversFor(release);
  for (final voice in all) {
    if (voice.id == voiceId) return voice;
  }
  return all.first;
}
