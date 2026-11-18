import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/section_header.dart';

class RelatedReleases extends StatefulWidget {
  const RelatedReleases({
    super.key,
    required this.items,
    required this.onOpen,
    required this.compact,
  });

  final List<dynamic> items;
  final void Function(dynamic anime) onOpen;
  final bool compact;

  @override
  State<RelatedReleases> createState() => _RelatedReleasesState();
}

class _RelatedReleasesState extends State<RelatedReleases> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scroll(double delta) {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      (_controller.offset + delta)
          .clamp(0.0, _controller.position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'связанные релизы',
          subtitle: items.isEmpty
              ? 'пока ничего не связано с этим релизом'
              : '${releasesLabel(items.length)} · вся история в одном месте',
          trailing: widget.compact || items.length < 4
              ? null
              : Row(
                  children: [
                    _ScrollArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _scroll(-360),
                    ),
                    const SizedBox(width: 7),
                    _ScrollArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _scroll(360),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
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
                    color: AppColors.accent.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    size: 19,
                    color: AppColors.accentBright,
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
          SizedBox(
            height: 296,
            child: Scrollbar(
              controller: _controller,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final anime = items[index];
                  return SizedBox(
                    width: 150,
                    child: AnimeCard(
                      anime: anime,
                      dense: true,
                      onTap: () => widget.onOpen(anime),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.8),
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: AppColors.textSoft),
        ),
      ),
    );
  }
}
