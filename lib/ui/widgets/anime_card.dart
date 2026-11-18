import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_card_item.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import 'app_image.dart';
import 'skeleton.dart';

class AnimeCard extends StatefulWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.dense = false,
  });

  final dynamic anime; // AnimeRelease | ShikimoriAnime | ShikimoriAnimeDetails
  final VoidCallback onTap;
  final bool dense;

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final adapter = AnimeCardAdapter(widget.anime);
    final libraryId = adapter.libraryId;
    final status = libraryId != null ? library.statusOf(libraryId) : null;
    final favorite = libraryId != null ? library.isFavorite(libraryId) : false;
    final progress = libraryId != null ? library.progressFor(libraryId) : null;

    final pillLabel = status != null
        ? (status == CollectionStatus.watching && progress != null
              ? '${status.label} · ${progress.episode} серия'
              : status.label)
        : (adapter.isOngoing ? 'онгоинг' : null);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1,
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hovered
                          ? AppColors.accent.withValues(alpha: 0.55)
                          : AppColors.border,
                    ),
                    boxShadow: _hovered
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 12),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedScale(
                          scale: _hovered ? 1.045 : 1,
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          child: AppImage(
                            url: adapter.posterUrl,
                            memCacheWidth: 520,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x1A000000),
                                Color(0x00000000),
                                Color(0x99000000),
                              ],
                              stops: [0, 0.55, 1],
                            ),
                          ),
                        ),
                        if (_hovered) const Center(child: _HoverPlay()),
                        if (pillLabel != null)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: _GlassPill(
                              label: pillLabel,
                              accent: status == null,
                            ),
                          ),
                        if (favorite)
                          const Positioned(
                            right: 8,
                            top: 8,
                            child: _FavoriteMark(),
                          ),
                        if (adapter.ageRating != null)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: _GlassPill(
                              label: adapter.ageRating!,
                              muted: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: widget.dense ? 7 : 9),
              Text(
                adapter.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w500,
                  fontSize: widget.dense ? 11.5 : 12.5,
                  height: 1.25,
                  letterSpacing: -0.2,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (adapter.score != null) ...[
                    const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      formatScore(adapter.score),
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      [
                        if (adapter.year != null) '${adapter.year}',
                        if (adapter.episodeCount != null)
                          '${adapter.episodeCount} сер.',
                        if (adapter.score == null && adapter.year == null)
                          adapter.statusLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverPlay extends StatelessWidget {
  const _HoverPlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.55),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class _FavoriteMark extends StatelessWidget {
  const _FavoriteMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: 14,
        color: AppColors.accentBright,
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.label,
    this.accent = false,
    this.muted = false,
  });

  final String label;
  final bool accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.92)
            : AppColors.background.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label.toLowerCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 9.5,
          height: 1.1,
          color: muted ? AppColors.textSoft : Colors.white,
        ),
      ),
    );
  }
}

class SliverAnimeGrid extends StatelessWidget {
  const SliverAnimeGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.dense = false,
    this.maxColumns = 8,
  });

  final List<dynamic> items;
  final void Function(dynamic anime) onTap;
  final bool dense;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = (width / (dense ? 164 : 184))
            .floor()
            .clamp(2, maxColumns)
            .toInt();
        final spacing = width < 600 ? 12.0 : 18.0;
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        final extent = tileWidth * 1.5 + (dense ? 58 : 68);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: width < 600 ? 20 : 26,
            mainAxisExtent: extent,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final anime = items[index];
            return AnimeCard(
              anime: anime,
              onTap: () => onTap(anime),
              dense: dense,
            );
          }, childCount: items.length),
        );
      },
    );
  }
}

class SliverAnimeGridSkeleton extends StatelessWidget {
  const SliverAnimeGridSkeleton({super.key, this.count = 12});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = (width / 184).floor().clamp(2, 8).toInt();
        final spacing = width < 600 ? 12.0 : 18.0;
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: width < 600 ? 20 : 26,
            mainAxisExtent: tileWidth * 1.5 + 68,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const AnimeCardSkeleton(),
            childCount: count,
          ),
        );
      },
    );
  }
}
