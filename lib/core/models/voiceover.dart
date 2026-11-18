// Common interface for voiceover/dub information across all sources.
import 'anime_release.dart';
import '../utils/format.dart';

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
}

/// AniLibria-specific voiceover (wraps ReleaseMember)
class AniLibriaVoiceover implements VoiceoverInfo {
  const AniLibriaVoiceover(this._releaseMember);

  final ReleaseMember _releaseMember;

  @override
  String get id => 'anilibria_${_releaseMember.nickname}';

  @override
  String get title => lc(_releaseMember.nickname);

  @override
  String get subtitle => lc(_releaseMember.roleLabel);

  @override
  String get source => 'anilibria';

  /// Access to original ReleaseMember for AniLibria-specific data
  ReleaseMember get releaseMember => _releaseMember;
}

/// Generic voiceover for other sources (AnimeVost, AniDub, Kodik, etc.)
class GenericVoiceover implements VoiceoverInfo {
  const GenericVoiceover({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.source,
  });

  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final String source;
}

/// Legacy compatibility: AnimeVoiceover used by playback_sheet and player_screen.
/// @deprecated Use VoiceoverInfo implementations instead.
@Deprecated('Use VoiceoverInfo implementations (AniLibriaVoiceover, GenericVoiceover) instead')
class AnimeVoiceover implements VoiceoverInfo {
  const AnimeVoiceover({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.source,
  });

  @override
  final String id;

  @override
  final String title;

  @override
  final String subtitle;

  @override
  final String source;

  String get displayName => title;

  static AnimeVoiceover empty() => const AnimeVoiceover(
    id: '',
    title: '',
    subtitle: '',
    source: '',
  );
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
      title: 'русская озвучка',
      subtitle: 'anilibria · $cast',
      source: 'anilibria',
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