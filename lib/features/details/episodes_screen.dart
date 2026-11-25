import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_episode.dart';
import '../../core/models/anime_source.dart';
import '../../core/models/voiceover.dart';
import '../../core/repository/unified_repository.dart';
import '../../core/services/app_services.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/episode_card.dart';
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
  late final UnifiedRepository _repository;
  AnimeWithSources? _anime;
  bool _loading = false;
  String? _error;

  // Pagination for episodes
  static const int _episodesPerPage = 20;
  int _visibleCount = _episodesPerPage;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repository = context.read<AppServices>().repository;
    _anime = widget.animeWithSources;
    if (_anime == null) _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  int get _episodeTotal {
    final anime = _anime;
    if (anime == null) return 0;
    final voice = _voiceFor(anime);
    if (voice == null) return 0;
    return _sourceFor(anime, voice)?.episodes.length ?? 0;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 420) return;
    _loadMoreEpisodes();
  }

  Future<void> _loadMoreEpisodes() async {
    if (_loadingMore || _visibleCount >= _episodeTotal) return;
    setState(() => _loadingMore = true);
    // A tiny pause keeps the reveal intentional instead of dumping every
    // remaining episode in one frame while the finger is still moving.
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() {
      _visibleCount += _episodesPerPage;
      _loadingMore = false;
    });
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
      setState(() {
        _anime = anime;
        _visibleCount = _episodesPerPage;
        _loadingMore = false;
      });
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
          controller: _scrollController,
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
                  itemCount: _visibleCount < episodes.length
                      ? _visibleCount + (_loadingMore ? 1 : 0)
                      : episodes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (_loadingMore && index >= _visibleCount) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(
                            color: AppColors.accentBright,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    final episode = episodes[index];
                    final isCurrent =
                        progress != null && progress.episode == episode.ordinal;
                    return EpisodeCard(
                      episode: episode,
                      current: isCurrent,
                      currentLabel: 'продолжить',
                      compact: compact,
                      onTap: episode.hasStream
                          ? () => _play(anime, source, episode)
                          : null,
                    );
                  },
                ),
              ),
            if (!_loadingMore && _visibleCount < episodes.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'показано $_visibleCount из ${episodes.length} ${_episodesLabel(episodes.length)}',
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
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
