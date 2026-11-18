import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: compact ? 16 : 22,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toLowerCase(),
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 16 : 21,
                  letterSpacing: -0.5,
                  color: AppColors.text,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!.toLowerCase(),
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
