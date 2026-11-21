import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_card_item.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import 'app_image.dart';
import 'skeleton.dart';

/// Compact, scannable list rendering of anime entries.
class SliverAnimeList extends StatelessWidget {
  const SliverAnimeList({super.key, required this.items, required this.onTap});

  final List<dynamic> items;
  final void Function(dynamic anime) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final anime = items[index];
        return AnimeListTile(anime: anime, onTap: () => onTap(anime));
      },
    );
  }
}

class AnimeListTile extends StatefulWidget {
  const AnimeListTile({super.key, required this.anime, required this.onTap});

  final dynamic anime;
  final VoidCallback onTap;

  @override
  State<AnimeListTile> createState() => _AnimeListTileState();
}

class _AnimeListTileState extends State<AnimeListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final adapter = AnimeCardAdapter(widget.anime);
    final libraryId = adapter.libraryId;
    final status = libraryId != null ? library.statusOf(libraryId) : null;
    final favorite = libraryId != null && library.isFavorite(libraryId);
    final progress = libraryId != null ? library.progressFor(libraryId) : null;

    final meta = <String>[
      if (adapter.year != null) '${adapter.year}',
      if (adapter.episodeCount != null && adapter.episodeCount! > 0)
        '${adapter.episodeCount} сер.',
      if (adapter.statusLabel.isNotEmpty) adapter.statusLabel,
    ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceHigh.withValues(alpha: 0.9)
              : AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? AppColors.accent.withValues(alpha: 0.42)
                : AppColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: AppImage(
                        url: adapter.posterUrl,
                        borderRadius: BorderRadius.circular(10),
                        memCacheWidth: 240,
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
                          adapter.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                            height: 1.2,
                            letterSpacing: -0.25,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            if (adapter.score != null &&
                                adapter.score! > 0) ...[
                              const Icon(
                                AppIcons.star,
                                size: 13,
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
                              const SizedBox(width: 9),
                            ],
                            Expanded(
                              child: Text(
                                meta.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            if (favorite)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  AppIcons.heart,
                                  size: 14,
                                  color: AppColors.accentBright,
                                ),
                              ),
                          ],
                        ),
                        if (status != null) ...[
                          const SizedBox(height: 8),
                          _StatusPill(
                            status: status,
                            episode: progress?.episode,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    AppIcons.caretRight,
                    size: 20,
                    color: _hovered
                        ? AppColors.accentBright
                        : AppColors.textFaint,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.episode});

  final CollectionStatus status;
  final int? episode;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CollectionStatus.planned => AppColors.planned,
      CollectionStatus.watching => AppColors.watching,
      CollectionStatus.completed => AppColors.completed,
    };
    final label = status == CollectionStatus.watching && episode != null
        ? '${status.label} · $episode серия'
        : status.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label.toLowerCase(),
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class SliverAnimeListSkeleton extends StatelessWidget {
  const SliverAnimeListSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => const _ListTileSkeleton(),
    );
  }
}

class _ListTileSkeleton extends StatelessWidget {
  const _ListTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 58, height: 87, borderRadius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 13, borderRadius: 5),
                SizedBox(height: 10),
                SkeletonBox(width: 160, height: 10, borderRadius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
