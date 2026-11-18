import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

class SkeletonBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceHigh,
            AppColors.surfaceSoft.withValues(alpha: 0.55),
            AppColors.surfaceHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.border),
      ),
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
