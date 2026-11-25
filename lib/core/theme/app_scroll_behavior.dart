import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Adds mouse dragging to every scrollable.
///
/// Flutter desktop only scrolls with the wheel by default, which makes the
/// stills / related rails feel dead. With this behaviour a mouse behaves like
/// a finger: press, drag, release. Touch and trackpad keep working.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };

  /// The app never shows scrollbars: rails and pages stay visually clean.
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
