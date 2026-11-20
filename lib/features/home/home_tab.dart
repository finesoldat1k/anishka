import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';

enum HomeTab {
  airing('сейчас', AppIcons.playCircle),
  favorites('избранное', AppIcons.heart),
  watching('смотрю', AppIcons.eye),
  planned('в планах', AppIcons.bookmarkSimple),
  completed('просмотренно', AppIcons.checkCircle);

  const HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
