import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/widgets/app_image.dart';

/// Square studio avatar used by the voiceover list.
///
/// Uses the studio logo when it is known, otherwise a deterministic monogram.
/// Colours stay inside the neutral + semantic palette, so no purple.
class VoiceAvatar extends StatelessWidget {
  const VoiceAvatar({
    super.key,
    required this.title,
    this.logoUrl,
    this.size = 50,
    this.radius,
  });

  final String title;
  final String? logoUrl;
  final double size;
  final double? radius;

  static const _tones = <Color>[
    AppColors.planned,
    AppColors.watching,
    AppColors.completed,
    AppColors.favorite,
    AppColors.trailer,
    AppColors.textSoft,
  ];

  String get _initials {
    final words = title
        .replaceAll(RegExp(r'[\[\]()]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.characters.take(2).join().toUpperCase();
    }
    return words.take(2).map((word) => word.characters.first).join().toUpperCase();
  }

  Color get _tone {
    var sum = 0;
    for (final unit in title.codeUnits) {
      sum += unit;
    }
    return _tones[sum % _tones.length];
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final borderRadius = BorderRadius.circular(radius ?? size * 0.3);
    final fallback = Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: borderRadius,
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.29,
          letterSpacing: -0.5,
          color: tone,
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: logoUrl == null || logoUrl!.isEmpty
          ? fallback
          : ClipRRect(
              borderRadius: borderRadius,
              child: Container(
                color: AppColors.surfaceHigh,
                padding: EdgeInsets.all(size * 0.2),
                child: AppImage(
                  url: logoUrl,
                  fit: BoxFit.contain,
                  fallbackLabel: title,
                ),
              ),
            ),
    );
  }
}
