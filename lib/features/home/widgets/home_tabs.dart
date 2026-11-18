import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../home_tab.dart';

class HomeTabs extends StatelessWidget {
  const HomeTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.counts,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelected;
  final Map<HomeTab, int> counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: HomeTab.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = HomeTab.values[index];
          return _TabPill(
            tab: tab,
            selected: tab == selected,
            count: counts[tab],
            onTap: () => onSelected(tab),
          );
        },
      ),
    );
  }
}

class _TabPill extends StatefulWidget {
  const _TabPill({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final HomeTab tab;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final count = widget.count;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.accentGradient : null,
            color: selected
                ? null
                : (_hovered
                      ? AppColors.surfaceHigh
                      : AppColors.surface.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.18)
                  : (_hovered
                        ? AppColors.accent.withValues(alpha: 0.35)
                        : AppColors.border),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.tab.icon,
                size: 15,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSoft,
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.accentBright,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
