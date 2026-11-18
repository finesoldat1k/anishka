import 'package:flutter/widgets.dart';

const double kMaxContentWidth = 1640;

double pagePadding(double width) {
  if (width >= 1400) return 44;
  if (width >= 900) return 32;
  if (width >= 600) return 24;
  return 16;
}

bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 760;
