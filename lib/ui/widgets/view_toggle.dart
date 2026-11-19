import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

enum AnimeViewMode { grid, list }

class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.mode, required this.onChanged});

  final AnimeViewMode mode;
  final ValueChanged<AnimeViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.grid_view_rounded,
            tooltip: 'сетка',
            selected: mode == AnimeViewMode.grid,
            onTap: () => onChanged(AnimeViewMode.grid),
          ),
          const SizedBox(width: 3),
          _ToggleButton(
            icon: Icons.view_list_rounded,
            tooltip: 'список',
            selected: mode == AnimeViewMode.list,
            onTap: () => onChanged(AnimeViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 33,
            height: 30,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.40)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected ? AppColors.accentBright : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
