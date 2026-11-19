import 'package:flutter/painting.dart';

/// palette anishka: graphite dark theme with quiet grey controls.
///
/// Accent colours are reserved for *actions*: a button stays grey until it
/// does something meaningful (favourite, bookmark, play, destructive, ...).
/// This keeps the interface calm and makes every colour readable.
abstract final class AppColors {
  static const background = Color(0xFF09090B);
  static const backgroundLift = Color(0xFF0C0C0E);
  static const surface = Color(0xFF121214);
  static const surfaceHigh = Color(0xFF18181B);
  static const surfaceSoft = Color(0xFF222226);

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
  static const planned = Color(0xFF7AA2F7); // blue — plans / links / focus
  static const watching = Color(0xFF6EE7A8); // green — watching
  static const completed = Color(0xFF5EEAD4); // teal — completed
  static const trailer = Color(0xFFF87171); // red — trailer / destructive
  static const danger = Color(0xFFF87171);
  static const success = watching;
  static const gold = favorite;
  static const info = planned;

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF2B2B30), Color(0xFF1A1A1D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const posterGradient = LinearGradient(
    colors: [Color(0x0009090B), Color(0xCC09090B), Color(0xFF09090B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 0.82, 1],
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xEE111113), Color(0xF5141417)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
