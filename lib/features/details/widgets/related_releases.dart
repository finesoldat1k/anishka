import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart' show AppFonts;
import '../../../core/utils/format.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/skeleton.dart';

/// Related releases rail.
///
/// Plain typographic section: no card wrapper, no arrow buttons. The rail is a
/// real scrollable, so it can be dragged with a mouse as well as a finger
/// (see [AppScrollBehavior]). "смотреть все" is always visible and opens the
/// full page.
class RelatedReleases extends StatelessWidget {
  const RelatedReleases({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onViewAll,
    required this.compact,
    this.shikimoriId,
    this.title,
    this.loading = false,
  });

  final List<dynamic> items;
  final void Function(dynamic anime) onOpen;
  final VoidCallback onViewAll;
  final bool compact;
  final int? shikimoriId;
  final String? title;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final hasItems = items.isNotEmpty;
    final cardWidth = compact ? 138.0 : 156.0;
    final railHeight = cardWidth * 1.5 + (compact ? 54 : 62);

    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'связанные релизы',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 14 : 16,
                        letterSpacing: -0.4,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'загружаем связанные релизы...',
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
          SizedBox(height: compact ? 14 : 20),
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (context, index) =>
                  SizedBox(width: compact ? 10 : 14),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: cardWidth,
                  child: const AnimeCardSkeleton(),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'связанные релизы',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w500,
                      fontSize: compact ? 14 : 16,
                      letterSpacing: -0.4,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasItems
                        ? '${releasesLabel(items.length)} · вся история по порядку'
                        : 'в каталоге shikimori нет связанных релизов для этого тайтла.',
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
            if (hasItems)
              GestureDetector(
                onTap: onViewAll,
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'смотреть все',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontWeight: FontWeight.w500,
                            fontSize: compact ? 11.5 : 12,
                            color: AppColors.textSoft,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          AppIcons.arrowRight,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 14 : 20),
        if (!hasItems)
          Text(
            'в каталоге shikimori нет связанных релизов для этого тайтла.',
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          )
        else
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  SizedBox(width: compact ? 10 : 14),
              itemBuilder: (context, index) {
                final anime = items[index];
                return SizedBox(
                  width: cardWidth,
                  child: AnimeCard(
                    anime: anime,
                    dense: true,
                    onTap: () => onOpen(anime),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
