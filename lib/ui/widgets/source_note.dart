import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class SourceNote extends StatelessWidget {
  const SourceNote({
    super.key,
    this.padding = const EdgeInsets.only(top: 36, bottom: 24),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Text(
        'все права на аниме принадлежат правообладателям.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10.5,
          color: AppColors.textFaint,
        ),
      ),
    );
  }
}
