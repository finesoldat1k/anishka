import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _AmbientPainter())),
          child,
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    void glow(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(rect, paint);
    }

    glow(
      Offset(size.width * 0.08, -size.height * 0.12),
      math.max(size.width, size.height) * 0.75,
      AppColors.planned.withValues(alpha: 0.16),
    );
    glow(
      Offset(size.width * 1.02, size.height * 0.24),
      math.max(size.width, size.height) * 0.58,
      AppColors.planned.withValues(alpha: 0.10),
    );
    glow(
      Offset(size.width * 0.42, size.height * 1.08),
      math.max(size.width, size.height) * 0.62,
      AppColors.planned.withValues(alpha: 0.07),
    );

    final dotPaint = Paint()..color = const Color(0x08FFFFFF);
    const step = 38.0;
    for (var x = 18.0; x < size.width; x += step) {
      for (var y = 18.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
      }
    }

    final topFade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66000000), Color(0x00000000)],
        stops: [0, 0.18],
      ).createShader(rect);
    canvas.drawRect(rect, topFade);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => false;
}
