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

class _GradientButtonState extends State<GradientButton> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _pressController.forward();
      setState(() => _pressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  Color get _toneColor => switch (widget.tone) {
    GradientButtonTone.play => AppColors.planned, // Purple for play button
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
          ? tone // Fully opaque when active
          : _hovered
          ? tone.withValues(alpha: 0.15)
          : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: widget.active
            ? tone.withValues(alpha: 0.8)
            : _hovered
            ? tone.withValues(alpha: 0.5)
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
      onExit: (_) {
        setState(() => _hovered = false);
        if (_pressed) {
          _pressController.reverse();
          setState(() => _pressed = false);
        }
      },
      child: AnimatedScale(
        scale: _hovered && enabled ? 1.012 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 160),
          child: ScaleTransition(
            scale: _pressAnimation,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
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
      ),
    );
  }
}
