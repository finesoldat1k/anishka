import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_episode.dart';
import '../../core/models/anime_source.dart';
import '../../core/models/voiceover.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/app_image.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/source_note.dart';
import '../../ui/widgets/state_views.dart';
import 'widgets/subpage_header.dart';
import 'widgets/voice_avatar.dart';

/// Second step of playback: episodes of the selected voiceover.
///
/// Tapping an episode opens the player immediately — there is no extra
/// "смотреть серию" button.
class EpisodesScreen extends StatefulWidget {
  const EpisodesScreen({
    super.key,
    required this.voiceId,
    this.animeWithSources,
    this.shikimoriId,
  });

  final String voiceId;
  final AnimeWithSources? animeWithSources;
  final int? shikimoriId;

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  late final AnimeRepository _repository;
  AnimeWithSources? _anime;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AnimeRepository>();
    _anime = widget.animeWithSources;
    if (_anime == null) _load();
  }

  int? get _animeId => widget.shikimoriId ?? _anime?.shikimoriAnime.id;

  Future<void> _load() async {
    final id = _animeId;
    if (id == null || id <= 0) {
      setState(() => _error = 'не удалось определить аниме.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final anime = await _repository.getAnimeWithSources(id);
      if (!mounted) return;
      setState(() => _anime = anime);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _play(AnimeWithSources anime, AnimeSource source, AnimeEpisode episode) {
    final voice = source.voiceover;
    final library = context.read<LibraryStore>();
    library.saveProgress(
      releaseId: source.release.id,
      episode: episode.ordinal,
      voice: voice.id,
    );
    context.push(
      '/watch/${source.release.id}/${episode.ordinal}'
      '?voice=${Uri.encodeComponent(voice.id)}',
      extra: source,
    );
  }

  VoiceoverInfo? _voiceFor(AnimeWithSources anime) {
    for (final source in anime.sources) {
      if (source.voiceover.id == widget.voiceId) return source.voiceover;
    }
    // GoRouter may double-encode some ids; try a decoded variant as a fallback.
    final decoded = Uri.decodeComponent(widget.voiceId);
    for (final source in anime.sources) {
      if (source.voiceover.id == decoded) return source.voiceover;
    }
    return null;
  }

  AnimeSource? _sourceFor(AnimeWithSources anime, VoiceoverInfo voice) {
    for (final source in anime.sources) {
      if (source.voiceover.id == voice.id) return source;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final padding = pagePadding(width);
    final anime = _anime;
    final voice = anime == null ? null : _voiceFor(anime);
    final source = anime == null || voice == null
        ? null
        : _sourceFor(anime, voice);
    final library = context.watch<LibraryStore>();
    final episodes = source?.episodes.toList() ?? <AnimeEpisode>[];
    episodes.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    final progress = source == null
        ? null
        : library.progressFor(source.release.id);
    final totalDuration = episodes.fold<int>(
      0,
      (sum, episode) => sum + (episode.durationSeconds ?? 0),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: SubpageHeader(
                    eyebrow: 'воспроизведение · шаг 2',
                    title: voice?.title ?? 'серии',
                    subtitle: anime == null
                        ? null
                        : '${anime.displayTitle} · '
                              '${episodes.isEmpty ? 'серии не найдены' : '${episodes.length} ${_episodesLabel(episodes.length)}'}',
                    onBack: _back,
                    compact: compact,
                    leading: voice == null
                        ? null
                        : VoiceAvatar(
                            title: voice.title,
                            logoUrl: voice.logoUrl,
                            size: compact ? 42 : 50,
                          ),
                    trailing: voice == null
                        ? null
                        : _VoiceBadge(
                            voice: voice,
                            episodes: episodes.length,
                            duration: totalDuration,
                          ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: ErrorState(
                  message: _error!,
                  compact: true,
                  onRetry: _load,
                ),
              )
            else if (_loading && anime == null)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 22, padding, 0),
                      child: Column(
                        children: [
                          for (var index = 0; index < 6; index++) ...[
                            const SkeletonBox(height: 72, borderRadius: 14),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (anime == null || voice == null || source == null)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: AppIcons.waveform,
                  title: 'озвучка не найдена',
                  message:
                      'эта студия больше не отдаёт серии для этого тайтла. '
                      'вернитесь и выберите другую озвучку.',
                  compact: true,
                ),
              )
            else if (episodes.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: AppIcons.filmStrip,
                  title: 'серий пока нет',
                  message: 'у этой озвучки ещё нет доступных серий.',
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 0),
                sliver: SliverList.separated(
                  itemCount: episodes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    final isCurrent =
                        progress != null && progress.episode == episode.ordinal;
                    return _EpisodeRow(
                      episode: episode,
                      current: isCurrent,
                      compact: compact,
                      onTap: episode.hasStream
                          ? () => _play(anime, source, episode)
                          : null,
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: SourceNote(
                      padding: EdgeInsets.only(top: 28, bottom: 30),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _episodesLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'серия';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'серии';
    }
    return 'серий';
  }
}

class _VoiceBadge extends StatelessWidget {
  const _VoiceBadge({
    required this.voice,
    required this.episodes,
    required this.duration,
  });

  final VoiceoverInfo voice;
  final int episodes;
  final int duration;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      voice.source,
      '$episodes серий',
      if (duration > 0) formatDuration(Duration(seconds: duration)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        parts.join(' · ').toLowerCase(),
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    required this.episode,
    required this.current,
    required this.compact,
    required this.onTap,
  });

  final AnimeEpisode episode;
  final bool current;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

/// Episode row whose still fades in as a full-bleed background on hover,
/// with the title and metadata sitting on top of the frame.
class _EpisodeRowState extends State<_EpisodeRow>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _pressController.forward();
      setState(() => _pressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final enabled = widget.onTap != null;
    final preview = episode.previewUrl;
    final hasPreview = preview != null && preview.isNotEmpty;
    final showStill = hasPreview && (_hovered || widget.compact);
    final currentTone = AppColors.watching;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() => _hovered = false);
        if (_pressed) {
          _pressController.reverse();
          setState(() => _pressed = false);
        }
      },
      child: ScaleTransition(
        scale: _pressAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: widget.compact ? 68 : 78,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.current
                    ? currentTone.withValues(alpha: 0.10)
                    : _hovered
                    ? AppColors.surfaceHigh
                    : AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.current
                      ? currentTone.withValues(alpha: 0.38)
                      : _hovered
                      ? AppColors.watching.withValues(alpha: 0.32)
                      : AppColors.border,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPreview)
                    AnimatedOpacity(
                      opacity: showStill
                          ? (_hovered
                                ? 0.95
                                : widget.compact
                                ? 0.55
                                : 0)
                          : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: AnimatedScale(
                        scale: _hovered ? 1.035 : 1,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        child: AppImage(
                          url: preview,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          memCacheWidth: 900,
                        ),
                      ),
                    ),
                  if (hasPreview)
                    AnimatedOpacity(
                      opacity: showStill ? 1 : 0,
                      duration: const Duration(milliseconds: 240),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xF209090B),
                              Color(0xC409090B),
                              Color(0x7309090B),
                              Color(0x2E09090B),
                            ],
                            stops: [0, 0.42, 0.78, 1],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 12 : 16,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: widget.compact ? 32 : 42,
                          child: Text(
                            episode.ordinal.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w600,
                              fontSize: widget.compact ? 14 : 16,
                              letterSpacing: -0.4,
                              color: widget.current
                                  ? currentTone
                                  : showStill
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : _hovered
                                  ? AppColors.text
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                episode.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontWeight: FontWeight.w500,
                                  fontSize: widget.compact ? 12.5 : 14,
                                  letterSpacing: -0.2,
                                  color: !enabled
                                      ? AppColors.textFaint
                                      : showStill
                                      ? Colors.white
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'серия ${episode.ordinal}',
                                    style: TextStyle(
                                      fontFamily: AppFonts.body,
                                      fontSize: 10.5,
                                      color: showStill
                                          ? Colors.white.withValues(alpha: 0.68)
                                          : AppColors.textFaint,
                                    ),
                                  ),
                                  if (episode.duration != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '·',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: showStill
                                            ? Colors.white.withValues(
                                                alpha: 0.4,
                                              )
                                            : AppColors.textFaint,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formatDuration(episode.duration!),
                                      style: TextStyle(
                                        fontFamily: AppFonts.body,
                                        fontSize: 10.5,
                                        color: showStill
                                            ? Colors.white.withValues(
                                                alpha: 0.68,
                                              )
                                            : AppColors.textFaint,
                                      ),
                                    ),
                                  ],
                                  if (widget.current) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'продолжить',
                                      style: TextStyle(
                                        fontFamily: AppFonts.body,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                        color: currentTone,
                                      ),
                                    ),
                                  ],
                                  if (!enabled) ...[
                                    const SizedBox(width: 8),
                                    const Text(
                                      'недоступно',
                                      style: TextStyle(
                                        fontFamily: AppFonts.body,
                                        fontSize: 10,
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedOpacity(
                          opacity: enabled && _hovered ? 1 : 0.72,
                          duration: const Duration(milliseconds: 170),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 170),
                            width: widget.compact ? 32 : 36,
                            height: widget.compact ? 32 : 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: enabled && _hovered
                                  ? AppColors.watching.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: enabled && _hovered
                                    ? AppColors.watching.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Icon(
                              AppIcons.play,
                              size: widget.compact ? 17 : 19,
                              color: enabled
                                  ? (_hovered
                                        ? AppColors.watching
                                        : AppColors.textSoft)
                                  : AppColors.textFaint,
                            ),
                          ),
                        ),
                      ],
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
