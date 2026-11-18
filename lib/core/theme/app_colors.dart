import 'package:flutter/painting.dart';

/// палитра anishka: почти чёрный фон и фиолетовый акцент.
abstract final class AppColors {
  static const background = Color(0xFF060409);
  static const backgroundLift = Color(0xFF0B0710);
  static const surface = Color(0xFF100B18);
  static const surfaceHigh = Color(0xFF181122);
  static const surfaceSoft = Color(0xFF1E1630);

  static const accent = Color(0xFFA855F7);
  static const accentBright = Color(0xFFC084FC);
  static const accentDeep = Color(0xFF7C3AED);
  static const accentGlow = Color(0x66A855F7);

  static const text = Color(0xFFF5F1FA);
  static const textSoft = Color(0xFFC7BDD6);
  static const textMuted = Color(0xFF8F849F);
  static const textFaint = Color(0xFF655B74);

  static const border = Color(0x16FFFFFF);
  static const borderStrong = Color(0x2AFFFFFF);
  static const success = Color(0xFF4ADE80);
  static const danger = Color(0xFFFB7185);
  static const gold = Color(0xFFFBBF24);

  static const accentGradient = LinearGradient(
    colors: [Color(0xFFB26BFF), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const posterGradient = LinearGradient(
    colors: [Color(0x00060409), Color(0xCC060409), Color(0xFF060409)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 0.82, 1],
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xEE0D0914), Color(0xF5100B18)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
