import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Animated placeholder used while content is loading.
///
/// The highlight sweeps across the box so the interface feels alive instead of
/// showing static grey blocks. The animation is disabled when the platform
/// asks for reduced motion.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.margin,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  static const _highlight = Color(0xFF373129);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = reduceMotion ? 0.5 : _controller.value;
        final sweep = -2.0 + 3.0 * progress;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [
                AppColors.surfaceHigh,
                _highlight,
                AppColors.surfaceHigh,
              ],
              stops: const [0.18, 0.5, 0.82],
              begin: Alignment(sweep, -0.35),
              end: Alignment(sweep + 1, 0.35),
            ),
            border: Border.all(color: AppColors.border),
          ),
        );
      },
    );
  }
}

class AnimeCardSkeleton extends StatelessWidget {
  const AnimeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 2 / 3,
          child: SkeletonBox(borderRadius: 16),
        ),
        const SizedBox(height: 10),
        const SkeletonBox(height: 11, borderRadius: 5),
        const SizedBox(height: 6),
        FractionallySizedBox(
          widthFactor: 0.56,
          child: const SkeletonBox(height: 9, borderRadius: 5),
        ),
      ],
    );
  }
}
