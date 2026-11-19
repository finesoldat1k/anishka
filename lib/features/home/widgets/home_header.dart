import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Compact home header: a search preview and an entry point to "о приложении".
/// No brand mark here — it lives on the about page.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onSearchTap,
    required this.onAboutTap,
    this.compact = false,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onAboutTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: 'открыть поиск',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Text(
                          'поиск аниме',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (!compact)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            '/',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textFaint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'о приложении',
          child: Material(
            color: AppColors.surface.withValues(alpha: 0.74),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              onTap: onAboutTap,
              borderRadius: BorderRadius.circular(16),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
