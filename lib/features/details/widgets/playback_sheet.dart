import 'package:material_ui/material_ui.dart';

import '../../../core/models/anime_episode.dart';
import '../../../core/models/anime_release.dart';
import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/models/voiceover.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/app_image.dart';
import '../../../ui/widgets/gradient_button.dart';

class PlaybackSelection {
  const PlaybackSelection({
    required this.episode,
    required this.voice,
    required this.source,
  });

  final AnimeEpisode episode;
  final VoiceoverInfo voice;
  final AnimeSource source;
}

Future<PlaybackSelection?> showPlaybackSheet(
  BuildContext context, {
  AnimeRelease? release,
  AnimeWithSources? animeWithSources,
  AnimeSource? initialSource,
  int? initialEpisode,
  String? initialVoice,
}) {
  return showModalBottomSheet<PlaybackSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.74),
    useSafeArea: true,
    builder: (context) => _PlaybackSheet(
      release: release,
      animeWithSources: animeWithSources,
      initialSource: initialSource,
      initialEpisode: initialEpisode,
      initialVoice: initialVoice,
    ),
  );
}

class _PlaybackSheet extends StatefulWidget {
  const _PlaybackSheet({
    this.release,
    this.animeWithSources,
    this.initialSource,
    this.initialEpisode,
    this.initialVoice,
  });

  final AnimeRelease? release;
  final AnimeWithSources? animeWithSources;
  final AnimeSource? initialSource;
  final int? initialEpisode;
  final String? initialVoice;

  @override
  State<_PlaybackSheet> createState() => _PlaybackSheetState();
}

class _PlaybackSheetState extends State<_PlaybackSheet> {
  late final List<AnimeSource> _sources;
  late AnimeSource _source;
  late List<VoiceoverInfo> _voices;
  late VoiceoverInfo _voice;
  AnimeEpisode? _episode;

  bool get _isNewFlow => widget.animeWithSources != null;

  @override
  void initState() {
    super.initState();
    if (_isNewFlow) {
      _sources = widget.animeWithSources!.sources;
      _source = widget.initialSource ?? widget.animeWithSources!.defaultSource ?? _sources.first;
      _voices = _voiceOptions();
      _voice = _voiceById(_voices, widget.initialVoice) ?? _source.voiceover;
      _episode = _findInitialEpisode();
    } else if (widget.release != null) {
      _sources = const [];
      _voices = voiceoversFor(widget.release!).cast<VoiceoverInfo>();
      _voice = voiceoverById(widget.release!, widget.initialVoice);
      _episode = _findInitialEpisodeLegacy();
    }
  }

  List<VoiceoverInfo> _voiceOptions() {
    final seen = <String>{};
    final result = <VoiceoverInfo>[];
    for (final source in _sources) {
      final voice = source.voiceover;
      if (seen.add(voice.id)) result.add(voice);
    }
    return result;
  }

  VoiceoverInfo? _voiceById(List<VoiceoverInfo> voices, String? id) {
    if (id != null) {
      for (final voice in voices) {
        if (voice.id == id) return voice;
      }
    }
    return voices.isEmpty ? null : voices.first;
  }

  AnimeSource? _sourceForVoice(VoiceoverInfo voice) {
    for (final source in _sources) {
      if (source.voiceover.id == voice.id) return source;
    }
    return null;
  }

  void _selectVoice(VoiceoverInfo voice) {
    final source = _sourceForVoice(voice);
    setState(() {
      _voice = voice;
      if (source == null) return;
      _source = source;
      final ordinal = _episode?.ordinal;
      AnimeEpisode? next;
      for (final episode in source.episodes) {
        if (episode.ordinal == ordinal && episode.hasStream) {
          next = episode;
          break;
        }
      }
      next ??= _firstPlayable(source.episodes);
      _episode = next ?? (source.episodes.isEmpty ? null : source.episodes.first);
    });
  }

  AnimeEpisode? _firstPlayable(List<AnimeEpisode> episodes) {
    for (final episode in episodes) {
      if (episode.hasStream) return episode;
    }
    return null;
  }

  AnimeEpisode? _findInitialEpisode() {
    final episodes = _source.episodes;
    if (episodes.isEmpty) return null;
    final initial = widget.initialEpisode;
    if (initial != null) {
      for (final episode in episodes) {
        if (episode.ordinal == initial && episode.hasStream) return episode;
      }
    }
    return _firstPlayable(episodes) ?? episodes.first;
  }

  AnimeEpisode? _findInitialEpisodeLegacy() {
    final release = widget.release!;
    final episodes = release.episodes;
    if (episodes.isEmpty) return null;
    final initial = widget.initialEpisode;
    if (initial != null) {
      for (final episode in episodes) {
        if (episode.ordinal == initial && episode.hasStream) return episode;
      }
    }
    return _firstPlayable(episodes) ?? episodes.first;
  }

  void _start() {
    final episode = _episode;
    if (episode == null || !episode.hasStream) return;
    if (_isNewFlow) {
      Navigator.of(
        context,
      ).pop(PlaybackSelection(episode: episode, voice: _voice, source: _source));
      return;
    }
    final release = widget.release!;
    final source = AnimeSource(
      id: 'anilibria:${release.id}:${_voice.id}',
      shikimoriAnime: ShikimoriAnimeDetails.empty(),
      release: release,
      voiceover: _voice,
      sourceType: 'anilibria',
    );
    Navigator.of(
      context,
    ).pop(PlaybackSelection(episode: episode, voice: _voice, source: source));
  }

  String _voiceSubtitle(VoiceoverInfo voice) {
    final subtitle = voice.subtitle.trim();
    if (voice is AniLibriaVoiceover) {
      return subtitle.isEmpty
          ? 'озвучка · anilibria'
          : '${subtitle.toLowerCase()} · anilibria';
    }
    return subtitle.isEmpty ? voice.source : subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 720;
    final isNewFlow = widget.animeWithSources != null;
    final displayTitle = isNewFlow
        ? widget.animeWithSources!.displayTitle
        : widget.release?.displayTitle ?? '';
    final posterUrl = isNewFlow
        ? widget.animeWithSources!.posterUrl
        : widget.release?.posterUrl;
    final episodes = isNewFlow ? _source.episodes : widget.release!.episodes;
    final episode = _episode;
    final radius = compact
        ? const BorderRadius.vertical(top: Radius.circular(28))
        : BorderRadius.circular(28);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: media.height * 0.92,
        ),
        child: Container(
          margin: EdgeInsets.fromLTRB(
            compact ? 0 : 18,
            0,
            compact ? 0 : 18,
            compact ? 0 : 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundLift,
            borderRadius: radius,
            border: Border.all(
              color: compact ? Colors.transparent : AppColors.borderStrong,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.10),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 26,
                12,
                compact ? 18 : 26,
                compact ? 22 + MediaQuery.paddingOf(context).bottom : 26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'воспроизведение',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            letterSpacing: -0.5,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.close_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: AppImage(
                            url: posterUrl,
                            borderRadius: BorderRadius.circular(8),
                            memCacheWidth: 160,
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                height: 1.25,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              isNewFlow ? _source.voiceCastLabel : widget.release!.primaryMeta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isNewFlow && _sources.length > 1) ...[
                    _SourceSummary(
                      count: _sources.length,
                      labels: _sources.map((s) => s.sourceType).toSet().toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _SheetLabel(
                    icon: Icons.graphic_eq_rounded,
                    label: 'озвучка',
                  ),
                  const SizedBox(height: 10),
                  if (_voices.isEmpty)
                    const _NoVoices()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final voice in _voices)
                          _VoiceChip(
                            voice: voice,
                            subtitle: _voiceSubtitle(voice),
                            selected: voice.id == _voice.id,
                            onTap: () => _selectVoice(voice),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const _SheetLabel(
                        icon: Icons.video_collection_outlined,
                        label: 'серия',
                      ),
                      const Spacer(),
                      Text(
                        episodes.isEmpty
                            ? 'пока нет серий'
                            : '${episodes.length} доступно',
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  if (episodes.isEmpty)
                    const _NoEpisodes()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in episodes)
                          _EpisodeChip(
                            episode: item,
                            selected: item.id == episode?.id,
                            onTap: item.hasStream
                                ? () => setState(() => _episode = item)
                                : null,
                          ),
                      ],
                    ),
                  if (episode != null) ...[
                    const SizedBox(height: 20),
                    _EpisodePreview(episode: episode),
                  ],
                  const SizedBox(height: 18),
                  GradientButton(
                    label: episode == null
                        ? 'серии ещё не вышли'
                        : 'смотреть серию ${episode.ordinal}',
                    icon: Icons.play_arrow_rounded,
                    expand: true,
                    height: 50,
                    onTap: episode != null && episode.hasStream ? _start : null,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'выбранная озвучка запомнится для этого аниме',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 10.5,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.accentBright),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.4,
            color: AppColors.textSoft,
          ),
        ),
      ],
    );
  }
}

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({
    required this.voice,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final VoiceoverInfo voice;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: subtitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.22),
                        AppColors.accentDeep.withValues(alpha: 0.10),
                      ],
                    )
                  : null,
              color: selected ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.55)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 15,
                  color: selected
                      ? AppColors.accentBright
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  voice.title,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: selected ? AppColors.text : AppColors.textSoft,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.accentBright,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceSummary extends StatelessWidget {
  const _SourceSummary({required this.count, required this.labels});

  final int count;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final sources = labels.isEmpty ? 'источники' : labels.join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.source_rounded,
            size: 15,
            color: AppColors.accentBright,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'доступно вариантов: $count · $sources',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoVoices extends StatelessWidget {
  const _NoVoices();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'для этого тайтла пока нет озвучек с доступными сериями.',
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 11.5,
          height: 1.4,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({
    required this.episode,
    required this.selected,
    required this.onTap,
  });

  final AnimeEpisode episode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: episode.hasStream ? 'серия ${episode.ordinal}' : 'нет источника',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 43,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected ? AppColors.accentGradient : null,
              color: selected ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.border,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 13,
                      ),
                    ]
                  : null,
            ),
            child: Opacity(
              opacity: onTap == null && !selected ? 0.35 : 1,
              child: Text(
                '${episode.ordinal}',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSoft,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodePreview extends StatelessWidget {
  const _EpisodePreview({required this.episode});

  final AnimeEpisode episode;

  @override
  Widget build(BuildContext context) {
    final duration = episode.duration;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 8.2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (episode.previewUrl != null)
              AppImage(url: episode.previewUrl, memCacheWidth: 900)
            else
              const ColoredBox(
                color: AppColors.surface,
                child: Center(
                  child: Icon(
                    Icons.movie_filter_outlined,
                    color: AppColors.textFaint,
                    size: 34,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC060409)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      episode.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w500,
                        fontSize: 11.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        formatDuration(duration),
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoEpisodes extends StatelessWidget {
  const _NoEpisodes();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'серии ещё не добавили. как только они появятся, кнопка воспроизведения станет активной.',
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          height: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
