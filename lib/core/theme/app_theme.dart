import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const display = 'Unbounded';
  static const body = 'Onest';
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    primaryContainer: AppColors.accentDeep,
    onPrimaryContainer: Colors.white,
    secondary: AppColors.accentBright,
    onSecondary: Colors.black,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.borderStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: AppColors.surface,
    splashFactory: InkSparkle.splashFactory,
  );

  const display = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    height: 1.02,
    color: AppColors.text,
  );
  const heading = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    height: 1.1,
    color: AppColors.text,
  );
  const title = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.2,
    color: AppColors.text,
  );
  const body = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.textSoft,
  );

  final textTheme = TextTheme(
    displayLarge: display.copyWith(fontSize: 64),
    displayMedium: display.copyWith(fontSize: 48),
    displaySmall: display.copyWith(fontSize: 36),
    headlineLarge: heading.copyWith(fontSize: 32),
    headlineMedium: heading.copyWith(fontSize: 26),
    headlineSmall: heading.copyWith(fontSize: 22),
    titleLarge: title.copyWith(fontSize: 20),
    titleMedium: title.copyWith(fontSize: 16),
    titleSmall: title.copyWith(fontSize: 14),
    bodyLarge: body.copyWith(fontSize: 16),
    bodyMedium: body.copyWith(fontSize: 14),
    bodySmall: body.copyWith(fontSize: 12.5, color: AppColors.textMuted),
    labelLarge: const TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.1,
      color: AppColors.text,
    ),
    labelMedium: const TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      letterSpacing: 0.2,
      color: AppColors.textSoft,
    ),
    labelSmall: const TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w500,
      fontSize: 10.5,
      letterSpacing: 0.3,
      color: AppColors.textMuted,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.text),
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.display,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.text,
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.textSoft, size: 20),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      modalBarrierColor: Color(0xB3000000),
      elevation: 0,
      showDragHandle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      insetPadding: const EdgeInsets.all(20),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderStrong),
      ),
      textStyle: textTheme.labelMedium?.copyWith(color: AppColors.text),
      waitDuration: const Duration(milliseconds: 500),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
      thumbColor: AppColors.accentBright,
      overlayColor: AppColors.accent.withValues(alpha: 0.16),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceSoft,
      circularTrackColor: AppColors.surfaceSoft,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.14)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSoft,
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.borderStrong),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSoft,
        highlightColor: AppColors.accent.withValues(alpha: 0.12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface.withValues(alpha: 0.86),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      prefixIconColor: AppColors.textMuted,
      suffixIconColor: AppColors.textMuted,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textMuted,
      textColor: AppColors.text,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
