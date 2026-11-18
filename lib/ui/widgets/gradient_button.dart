import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expand = false,
    this.ghost = false,
    this.height = 48,
    this.badge,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expand;
  final bool ghost;
  final double height;
  final Widget? badge;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: Colors.white),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Text(
            widget.label.toLowerCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.1,
              color: Colors.white,
            ),
          ),
        ),
        if (widget.badge != null) ...[const SizedBox(width: 9), widget.badge!],
      ],
    );

    final decoration = widget.ghost
        ? BoxDecoration(
            color: _hovered ? AppColors.surfaceHigh : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : AppColors.borderStrong,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          )
        : BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(
                  alpha: _hovered ? 0.42 : 0.24,
                ),
                blurRadius: _hovered ? 28 : 18,
                spreadRadius: _hovered ? 3 : 1,
                offset: const Offset(0, 7),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered && enabled ? 1.012 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: widget.height,
                width: widget.expand ? double.infinity : null,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.expand ? 20 : 22,
                ),
                decoration: decoration,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
