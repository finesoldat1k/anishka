import 'dart:ui';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_release.dart';
import '../../core/models/anime_source.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/repository/unified_repository.dart';
import '../../core/services/app_services.dart';
import '../../core/storage/library_store.dart';
import '../../core/storage/search_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/source_note.dart';
import '../../ui/widgets/state_views.dart';
import 'widgets/details_hero.dart';
import 'widgets/details_body.dart';
import 'widgets/related_releases.dart';
import 'widgets/trailer_section.dart';
import 'related_screen.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.shikimoriId, this.preview});

  final int shikimoriId;

  /// Compact search/home result used for instant first paint.
  final ShikimoriAnime? preview;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final UnifiedRepository _repository;
  AnimeWithSources? _anime;
  bool _loading = true;
  bool _fullDataLoaded = false;
  bool _refreshing = false;
  String? _error;
  bool _visitedSaved = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AppServices>().repository;
    final preview = widget.preview;
    final cached = _repository.cachedAnimeWithSources(widget.shikimoriId);
    if (cached != null) {
      _anime = cached;
      _loading = false;
    } else if (preview != null) {
      _anime = AnimeWithSources(
        shikimoriAnime: preview.toDetailsPreview(),
        sources: const [],
        related: const [],
      );
      _loading = false;
    }
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else if (_anime == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final full = await _repository.getAnimeWithSources(
        widget.shikimoriId,
        refresh: refresh,
        titleHint: widget.preview?.displayTitle,
        // During pull-to-refresh keep the current full page on screen instead
        // of replacing it with an empty partial result.
        onPartial: refresh
            ? null
            : (partial) {
                if (!mounted) return;
                _applyBase(partial.shikimoriAnime);
              },
      );
      if (!mounted) return;
      _applyFull(full.shikimoriAnime, full);
    } catch (error) {
      if (!mounted) return;
      if (_anime == null) {
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

  void _applyBase(ShikimoriAnimeDetails details) {
    _rememberVisited(details);
    setState(() {
      _anime = AnimeWithSources(
        shikimoriAnime: details,
        sources: const [],
        related: const [],
      );
      _loading = false;
      _fullDataLoaded = false;
      _error = null;
    });
  }

  void _applyFull(ShikimoriAnimeDetails details, AnimeWithSources full) {
    _rememberVisited(details);
    final defaultSource = full.defaultSource;
    final library = context.read<LibraryStore>();
    if (defaultSource != null) {
      // Move favourite/status from temporary snapshot to real playable release.
      library.adoptEntry(-details.id, defaultSource.release);
      library.syncSnapshot(defaultSource.release);
    }
    setState(() {
      _anime = full;
      _fullDataLoaded = true;
      _error = null;
    });
  }

  void _rememberVisited(ShikimoriAnimeDetails anime) {
    if (_visitedSaved) return;
    _visitedSaved = true;
    context.read<SearchStore>().addVisited(anime);
  }

  AnimeRelease? get _librarySnapshot {
    final anime = _anime;
    if (anime == null) return null;
    return anime.defaultSource?.release ??
        AnimeRelease.fromShikimoriDetails(anime.shikimoriAnime);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _playFromSources() {
    final anime = _anime;
    if (anime == null) return;
    context.push(
      '/anime/shikimori/${anime.shikimoriAnime.id}/voices',
      extra: anime,
    );
  }

  void _openRelated(ShikimoriAnime anime) {
    context.push('/anime/shikimori/${anime.id}', extra: anime);
  }

  void _toggleFavorite() {
    final release = _librarySnapshot;
    if (release == null) return;
    context.read<LibraryStore>().toggleFavorite(release);
    // The store updates synchronously; rebuilding the page here makes the
    // heart flip in the same frame even if a provider notification is
    // coalesced with an in-flight refresh.
    setState(() {});
  }

  void _selectStatus(CollectionStatus status) {
    final release = _librarySnapshot;
    if (release == null) return;
    context.read<LibraryStore>().setStatus(release, status);
    setState(() {});
  }

  void _removeStatus() {
    final release = _librarySnapshot;
    if (release == null) return;
    context.read<LibraryStore>().setStatus(release, null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = pagePadding(width);
    final compact = width < 760;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          if (_loading && _anime == null)
            const _DetailsSkeleton()
          else if (_error != null && _anime == null)
            Center(
              child: ErrorState(
                message: _error!,
                onRetry: () => _load(refresh: true),
              ),
            )
          else if (_anime != null)
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
                    child: DetailsHero(
                      anime: _anime!,
                      librarySnapshot: _librarySnapshot,
                      compact: compact,
                      onPlay: _playFromSources,
                      onToggleFavorite: _toggleFavorite,
                      onSelectStatus: _selectStatus,
                      onRemoveStatus: _removeStatus,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(padding, 28, padding, 0),
                          child: DetailsBody(
                            anime: _anime!,
                            compact: compact,
                            loadingStills: !_fullDataLoaded,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_anime!.related.isNotEmpty || !_fullDataLoaded)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              24,
                              padding,
                              0,
                            ),
                            child: RelatedReleases(
                              items: _anime!.related,
                              onOpen: _openRelated,
                              onViewAll: () => context.push(
                                '/anime/shikimori/${widget.shikimoriId}/related',
                                extra: RelatedArgs(
                                  items: _anime!.related,
                                  title: _anime!.displayTitle,
                                ),
                              ),
                              compact: compact,
                              shikimoriId: widget.shikimoriId,
                              title: _anime!.displayTitle,
                              loading: !_fullDataLoaded,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Trailer section below related releases
                  if (_anime!.shikimoriAnime.trailerYoutubeId != null &&
                      _anime!.shikimoriAnime.trailerYoutubeId!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              16,
                              padding,
                              0,
                            ),
                            child: TrailerSection(
                              trailerYoutubeId:
                                  _anime!.shikimoriAnime.trailerYoutubeId,
                              trailerThumbnail:
                                  _anime!.shikimoriAnime.trailerThumbnail,
                              trailerTitle: _anime!.displayTitle,
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
                          padding: EdgeInsets.symmetric(horizontal: padding),
                          child: const SourceNote(),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            )
          else
            const SizedBox.shrink(),

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
                child: Icon(AppIcons.arrowLeft, size: 20),
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
    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
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
      ),
    );
  }
}
