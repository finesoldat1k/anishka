import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.label,
    this.icon,
    this.accent = false,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool accent;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 12,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.13)
            : AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.32)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: dense ? 12 : 13,
              color: accent ? AppColors.accentBright : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toLowerCase(),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w500,
              fontSize: dense ? 10.5 : 11.5,
              color: accent ? AppColors.accentBright : AppColors.textSoft,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}
