import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'gradient_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: compact ? 28 : 64,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 54 : 66,
                height: compact ? 54 : 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: compact ? 24 : 28,
                  color: AppColors.accentBright,
                ),
              ),
              SizedBox(height: compact ? 16 : 22),
              Text(
                title.toLowerCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  letterSpacing: -0.4,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message.toLowerCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                GradientButton(
                  label: actionLabel!,
                  icon: AppIcons.arrowRight,
                  onTap: onAction,
                  ghost: true,
                  height: 42,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.cloudSlash,
      title: 'не удалось загрузить',
      message: message,
      actionLabel: onRetry == null ? null : 'попробовать снова',
      onAction: onRetry,
      compact: compact,
    );
  }
}
