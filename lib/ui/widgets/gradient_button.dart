import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Semantic colour of an action. Grey is the resting state; the tone only
/// becomes visible when the action is active or hovered.
enum GradientButtonTone {
  neutral,
  play,
  favorite,
  planned,
  watching,
  completed,
  danger,
  trailer,
}

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expand = false,
    this.ghost = false,
    this.primary = false,
    this.tone = GradientButtonTone.neutral,
    this.active = false,
    this.height = 48,
    this.badge,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expand;
  final bool ghost;

  /// High-emphasis neutral button (used for the main "play" action).
  final bool primary;
  final GradientButtonTone tone;
  final bool active;
  final double height;
  final Widget? badge;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hovered = false;

  Color get _toneColor => switch (widget.tone) {
    GradientButtonTone.play => AppColors.watching,
    GradientButtonTone.favorite => AppColors.favorite,
    GradientButtonTone.planned => AppColors.planned,
    GradientButtonTone.watching => AppColors.watching,
    GradientButtonTone.completed => AppColors.completed,
    GradientButtonTone.danger => AppColors.danger,
    GradientButtonTone.trailer => AppColors.trailer,
    GradientButtonTone.neutral => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tone = _toneColor;
    final useTone = widget.active || _hovered;
    final primary = widget.primary && !widget.ghost;

    final foreground = primary
        ? (useTone && widget.active ? AppColors.background : AppColors.background)
        : useTone
        ? tone
        : AppColors.text;
    final iconColor = primary ? AppColors.background : foreground;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: iconColor),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Text(
            widget.label.toLowerCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.1,
              color: foreground,
            ),
          ),
        ),
        if (widget.badge != null) ...[const SizedBox(width: 9), widget.badge!],
      ],
    );

    final decoration = BoxDecoration(
      color: primary
          ? (useTone ? const Color(0xFFE4E4E7) : AppColors.text)
          : widget.active
          ? tone.withValues(alpha: 0.14)
          : _hovered
          ? AppColors.surfaceSoft
          : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: widget.active
            ? tone.withValues(alpha: 0.48)
            : _hovered
            ? tone.withValues(alpha: 0.30)
            : AppColors.borderStrong,
      ),
      boxShadow: primary && _hovered
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
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
