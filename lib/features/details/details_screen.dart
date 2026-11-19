import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_franchise.dart';
import '../../core/models/anime_release.dart';
import '../../core/models/anime_source.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/source_note.dart';
import '../../ui/widgets/state_views.dart';
import 'widgets/details_body.dart';
import 'widgets/details_hero.dart';
import 'widgets/playback_sheet.dart';
import 'widgets/related_releases.dart';
import 'related_screen.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, this.releaseId, this.shikimoriId});

  final int? releaseId;
  final int? shikimoriId;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final AnimeRepository _repository;
  AnimeWithSources? _animeWithSources;
  AnimeRelease? _release; // For legacy AniLibria-only flow
  List<dynamic> _related = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AnimeRepository>();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      if (widget.shikimoriId != null) {
        // Shikimori-based flow: get anime with all sources
        final animeWithSources = await _repository.getAnimeWithSources(
          widget.shikimoriId!,
          refresh: refresh,
        );
        if (!mounted) return;
        // Sync library for the primary source if available
        final defaultSource = animeWithSources.defaultSource;
        if (defaultSource != null) {
          context.read<LibraryStore>().syncSnapshot(defaultSource.release);
        }
        setState(() {
          _animeWithSources = animeWithSources;
          _release = defaultSource?.release;
          _related = animeWithSources.related;
          _error = null;
        });
      } else if (widget.releaseId != null) {
        // Legacy AniLibria-only flow
        final releaseFuture = _repository.release(
          widget.releaseId!,
          refresh: refresh,
        );
        final franchiseFuture = _repository
            .franchises(widget.releaseId!, refresh: refresh)
            .catchError((Object _) => <AnimeFranchise>[]);

        final release = await releaseFuture;
        final franchises = await franchiseFuture;
        if (!mounted) return;
        context.read<LibraryStore>().syncSnapshot(release);
        setState(() {
          _release = release;
          _related = relatedReleasesFor(franchises, release.id);
          _error = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (_animeWithSources == null && _release == null) {
        setState(() => _error = userMessage(error));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _playFromSources() async {
    final anime = _animeWithSources;
    if (anime == null) return;
    context.push(
      '/anime/shikimori/${anime.shikimoriAnime.id}/voices',
      extra: anime,
    );
  }

  Future<void> _playLegacy() async {
    final library = context.read<LibraryStore>();
    final release = _release;
    if (release == null) return;

    final selection = await showPlaybackSheet(
      context,
      release: release,
      initialEpisode: library.lastEpisodeFor(release.id),
      initialVoice: library.voiceFor(release.id),
    );
    if (!mounted || selection == null) return;
    library.saveProgress(
      releaseId: release.id,
      episode: selection.episode.ordinal,
      voice: selection.voice.id,
    );
    context.push(
      '/watch/${release.id}/${selection.episode.ordinal}?voice=${selection.voice.id}',
      extra: selection.source,
    );
  }

  void _openRelated(dynamic anime) {
    if (anime is AnimeRelease) {
      context.push('/anime/${anime.id}');
    } else if (anime is ShikimoriAnime) {
      context.push('/anime/shikimori/${anime.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = pagePadding(width);
    final compact = width < 760;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (_loading && _animeWithSources == null && _release == null)
            const _DetailsSkeleton()
          else if (_error != null && _animeWithSources == null && _release == null)
            Center(
              child: ErrorState(message: _error!, onRetry: () => _load()),
            )
          else if (_animeWithSources != null)
            RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              color: AppColors.accentBright,
              backgroundColor: AppColors.surfaceHigh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: DetailsHero.sources(
                      animeWithSources: _animeWithSources!,
                      compact: compact,
                      onPlay: _playFromSources,
                      onToggleFavorite: () {
                        final source = _animeWithSources!.defaultSource;
                        if (source != null) {
                          context.read<LibraryStore>().toggleFavorite(source.release);
                        }
                      },
                      onSelectStatus: (status) {
                        final source = _animeWithSources!.defaultSource;
                        if (source != null) {
                          context.read<LibraryStore>().setStatus(source.release, status);
                        }
                      },
                      onRemoveStatus: () {
                        final source = _animeWithSources!.defaultSource;
                        if (source != null) {
                          context.read<LibraryStore>().setStatus(source.release, null);
                        }
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 28, padding, 0),
                          child: DetailsBody.sources(
                            animeWithSources: _animeWithSources!,
                            compact: compact,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_related.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                            child: _RelatedBlock(
                              compact: compact,
                              child: RelatedReleases(
                                items: _related,
                                onOpen: _openRelated,
                                onViewAll: _related.isNotEmpty && _release?.shikimoriId != null
                                    ? () => context.push(
                                          '/anime/shikimori/${_release!.shikimoriId}/related',
                                          extra: RelatedArgs(
                                            items: _related,
                                            title: _release!.displayTitle,
                                          ),
                                        )
                                    : () {},
                                compact: compact,
                                shikimoriId: _release?.shikimoriId,
                                title: _release?.displayTitle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: padding),
                          child: const SourceNote(),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            )
          else if (_release != null)
            RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              color: AppColors.accentBright,
              backgroundColor: AppColors.surfaceHigh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: DetailsHero.legacy(
                      release: _release!,
                      compact: compact,
                      onPlay: _playLegacy,
                      onToggleFavorite: () => context
                          .read<LibraryStore>()
                          .toggleFavorite(_release!),
                      onSelectStatus: (status) => context
                          .read<LibraryStore>()
                          .setStatus(_release!, status),
                      onRemoveStatus: () => context
                          .read<LibraryStore>()
                          .setStatus(_release!, null),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 28, padding, 0),
                          child: DetailsBody.legacy(
                            release: _release!,
                            compact: compact,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                          child: _RelatedBlock(
                            compact: compact,
                            child: RelatedReleases(
                              items: _related,
                              onOpen: _openRelated,
                              onViewAll: _related.isNotEmpty && _release?.shikimoriId != null
                                  ? () => context.push(
                                        '/anime/shikimori/${_release!.shikimoriId}/related',
                                        extra: RelatedArgs(
                                          items: _related,
                                          title: _release!.displayTitle,
                                        ),
                                      )
                                  : () {},
                              compact: compact,
                              shikimoriId: _release?.shikimoriId,
                              title: _release?.displayTitle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: padding),
                          child: const SourceNote(),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          Positioned(
            left: compact ? 14 : 22,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: compact ? 10 : 16),
                child: _BackButton(onTap: _back),
              ),
            ),
          ),
          if (_refreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.borderStrong),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'обновляем',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 10.5,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RelatedBlock extends StatelessWidget {
  const _RelatedBlock({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceHigh.withValues(alpha: 0.5),
            AppColors.surface.withValues(alpha: 0.62),
            AppColors.backgroundLift.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'назад',
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: AppColors.background.withValues(alpha: 0.45),
            shape: const CircleBorder(
              side: BorderSide(color: Color(0x33FFFFFF)),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: compact ? 460 : 490, borderRadius: 0),
          Padding(
            padding: EdgeInsets.all(compact ? 18 : 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: compact ? 112 : 218,
                  height: compact ? 168 : 327,
                  borderRadius: 18,
                ),
                const SizedBox(width: 28),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 20),
                      SizedBox(height: 14),
                      SkeletonBox(height: 12, borderRadius: 5),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12, borderRadius: 5),
                      SizedBox(height: 8),
                      SkeletonBox(width: 320, height: 12, borderRadius: 5),
                      SizedBox(height: 24),
                      SkeletonBox(width: 200, height: 32, borderRadius: 999),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
