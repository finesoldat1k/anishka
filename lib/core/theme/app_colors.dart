import 'package:flutter/painting.dart';

/// palette anishka: warm graphite dark theme with quiet grey controls.
///
/// Accent colours are reserved for *actions*: a button stays grey until it
/// does something meaningful (favourite, bookmark, play, destructive, ...).
/// This keeps the interface calm and makes every colour readable.
abstract final class AppColors {
  // Warm graphite palette - slightly warmer than pure black
  static const background = Color(0xFF0B0A09);
  static const backgroundLift = Color(0xFF12100D);
  static const surface = Color(0xFF171410);
  static const surfaceHigh = Color(0xFF1F1B16);
  static const surfaceSoft = Color(0xFF2B2620);

  /// Neutral emphasis (selected tab, focused control, secondary action).
  static const accent = Color(0xFFE4E4E7);
  static const accentBright = Color(0xFFFFFFFF);
  static const accentDeep = Color(0xFFA1A1AA);
  static const accentGlow = Color(0x26FFFFFF);

  static const text = Color(0xFFF4F4F5);
  static const textSoft = Color(0xFFC4C4C8);
  static const textMuted = Color(0xFF8A8A91);
  static const textFaint = Color(0xFF5F5F66);

  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x24FFFFFF);

  // Semantic action colours.
  static const favorite = Color(0xFFF5C84C); // amber — favourite
  static const planned = Color(0xFFA855F7); // purple — plans / bookmarks
  static const watching = Color(0xFF6EE7A8); // green — watching
  static const completed = Color(0xFF60A5FA); // blue — completed
  static const trailer = Color(0xFFF87171); // red — trailer / destructive
  static const danger = Color(0xFFF87171);
  static const success = watching;
  static const gold = favorite;
  static const info = planned;

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF2E2A32), Color(0xFF1E1C22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const posterGradient = LinearGradient(
    colors: [Color(0x000B0A09), Color(0xCC0B0A09), Color(0xFF0B0A09)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 0.82, 1],
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xEE131317), Color(0xF516161B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
