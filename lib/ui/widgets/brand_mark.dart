import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        'a',
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.55,
          height: 1,
          color: Colors.white,
        ),
      ),
    );

    if (!showName) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        const Text(
          'anishka',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: -0.6,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
