import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/gradient_button.dart';

class RelatedReleases extends StatelessWidget {
  const RelatedReleases({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onViewAll,
    required this.compact,
    this.shikimoriId,
    this.title,
  });

  final List<dynamic> items;
  final void Function(dynamic anime) onOpen;
  final VoidCallback onViewAll;
  final bool compact;
  final int? shikimoriId;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final hasItems = items.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with "смотреть все" button
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.planned.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.planned.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(Icons.link_rounded, size: 17, color: AppColors.planned),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'связанные релизы',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 15 : 17,
                      letterSpacing: -0.4,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasItems
                        ? '${releasesLabel(items.length)} · вся история по порядку'
                        : 'пока ничего не связано с этим релизом',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (hasItems && !compact)
              GradientButton(
                label: 'смотреть все',
                icon: Icons.arrow_forward_rounded,
                onTap: onViewAll,
                ghost: true,
                height: 36,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!hasItems)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.planned.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppColors.planned.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.link_off_rounded,
                    size: 19,
                    color: AppColors.planned,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'в каталоге shikimori пока нет связанных релизов.',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final anime = items[index];
              return SizedBox(
                width: 150,
                child: AnimeCard(
                  anime: anime,
                  dense: true,
                  onTap: () => onOpen(anime),
                ),
              );
            },
          ),
      ],
    );
  }
}