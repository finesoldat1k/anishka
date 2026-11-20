import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Calm Cupertino-like header for details subpages
/// (voiceovers, episodes, related releases).
class SubpageHeader extends StatelessWidget {
  const SubpageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.leading,
    this.trailing,
    this.compact = false,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 28,
        compact ? 12 : 20,
        compact ? 16 : 28,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BackCircle(onTap: onBack, size: compact ? 40 : 44),
          SizedBox(width: compact ? 12 : 16),
          if (leading != null) ...[
            leading!,
            SizedBox(width: compact ? 12 : 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow.toLowerCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
                    letterSpacing: 1.5,
                    color: AppColors.textFaint,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title.toLowerCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 19 : 24,
                    height: 1.12,
                    letterSpacing: -0.7,
                    color: AppColors.text,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!.toLowerCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap, required this.size});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      shape: CircleBorder(side: BorderSide(color: AppColors.borderStrong)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(
            AppIcons.arrowLeft,
            size: 19,
            color: AppColors.textSoft,
          ),
        ),
      ),
    );
  }
}
