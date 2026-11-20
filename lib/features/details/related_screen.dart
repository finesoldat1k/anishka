import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_card_item.dart';
import '../../core/models/anime_release.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/app_image.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/state_views.dart';
import 'widgets/subpage_header.dart';

/// Arguments passed to [RelatedScreen] through GoRouter `extra`.
class RelatedArgs {
  const RelatedArgs({required this.items, this.title});

  final List<dynamic> items;
  final String? title;
}

/// Full list of related releases, opened from the details rail.
class RelatedScreen extends StatefulWidget {
  const RelatedScreen({super.key, this.items, this.shikimoriId, this.title});

  final List<dynamic>? items;
  final int? shikimoriId;
  final String? title;

  @override
  State<RelatedScreen> createState() => _RelatedScreenState();
}

class _RelatedScreenState extends State<RelatedScreen> {
  late final AnimeRepository _repository;
  List<dynamic> _items = const [];
  bool _loading = false;
  String? _error;
  String? _animeTitle;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AnimeRepository>();
    _items = widget.items ?? const [];
    _animeTitle = widget.title;
    if (_items.isEmpty && widget.shikimoriId != null) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final id = widget.shikimoriId;
    if (id == null || id <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final anime = await _repository.getAnimeWithSources(id, refresh: refresh);
      if (!mounted) return;
      setState(() {
        _items = anime.related;
        _animeTitle ??= anime.displayTitle;
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

  void _open(dynamic anime) {
    if (anime is AnimeRelease) {
      context.push('/anime/${anime.id}');
    } else if (anime is ShikimoriAnime) {
      context.push('/anime/shikimori/${anime.id}', extra: anime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final padding = pagePadding(width);
    final hasItems = _items.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          color: AppColors.accentBright,
          backgroundColor: AppColors.surfaceHigh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: SubpageHeader(
                      eyebrow: 'франшиза',
                      title: _animeTitle ?? 'связанные релизы',
                      subtitle: hasItems
                          ? '${releasesLabel(_items.length)} · вся история по порядку'
                          : 'связанные релизы',
                      onBack: _back,
                      compact: compact,
                    ),
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: ErrorState(
                    message: _error!,
                    compact: true,
                    onRetry: () => _load(refresh: true),
                  ),
                )
              else if (_loading && !hasItems)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 186,
                          mainAxisExtent: 282,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const AnimeCardSkeleton(),
                      childCount: 8,
                    ),
                  ),
                )
              else if (!hasItems)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: AppIcons.linkBreak,
                    title: 'связей нет',
                    message:
                        'в каталоге shikimori пока нет связанных релизов '
                        'для этого тайтла.',
                    compact: true,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 28),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final anime = _items[index];
                      return _RelatedListTile(
                        anime: anime,
                        onTap: () => _open(anime),
                        compact: compact,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List tile for related releases with description snippet and larger poster.
class _RelatedListTile extends StatefulWidget {
  const _RelatedListTile({
    required this.anime,
    required this.onTap,
    required this.compact,
  });

  final dynamic anime; // ShikimoriAnime | AnimeRelease
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_RelatedListTile> createState() => _RelatedListTileState();
}

class _RelatedListTileState extends State<_RelatedListTile> with SingleTickerProviderStateMixin {
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
    _pressController.forward();
    setState(() => _pressed = true);
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
    final anime = widget.anime;
    final adapter = AnimeCardAdapter(anime);
    final year = adapter.year;
    final episodeCount = adapter.episodeCount;
    final score = adapter.score;
    final statusLabel = adapter.statusLabel;
    final posterUrl = adapter.posterUrl;
    final displayTitle = adapter.displayTitle;

    // Get description from ShikimoriAnime if available
    String? description;
    if (anime is ShikimoriAnimeDetails) {
      description = anime.descriptionText;
    } else if (anime is AnimeRelease) {
      description = anime.displayDescription;
    }

    // Clean and truncate description to 3 lines
    String? descriptionSnippet;
    if (description != null && description.isNotEmpty) {
      final cleaned = description
          .replaceAllMapped(
            RegExp(r'\[/?[a-z]+(?:=[^\]]*)?\]'),
            (match) => '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length > 200) {
        descriptionSnippet = '${cleaned.substring(0, 200)}…';
      } else if (cleaned.isNotEmpty) {
        descriptionSnippet = cleaned;
      }
    }

    final posterWidth = widget.compact ? 100.0 : 120.0;
    final posterHeight = posterWidth * 1.5;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(widget.compact ? 10 : 12),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.surfaceHigh
                  : AppColors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovered ? AppColors.borderStrong : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: posterWidth,
                  height: posterHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppImage(
                      url: posterUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: posterWidth.round() * 2,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w500,
                          fontSize: widget.compact ? 13.5 : 15,
                          height: 1.25,
                          letterSpacing: -0.25,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (score != null && score > 0) ...[
                            const Icon(
                              AppIcons.star,
                              size: 13,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              formatScore(score),
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSoft,
                              ),
                            ),
                            const SizedBox(width: 9),
                          ],
                          Expanded(
                            child: Text(
                              [
                                if (year != null) '$year',
                                if (episodeCount != null && episodeCount > 0)
                                  '$episodeCount сер.',
                                if (statusLabel.isNotEmpty) statusLabel,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (descriptionSnippet != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          descriptionSnippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: widget.compact ? 11.5 : 12.5,
                            height: 1.5,
                            color: AppColors.textSoft.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  AppIcons.caretRight,
                  size: 20,
                  color: AppColors.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}