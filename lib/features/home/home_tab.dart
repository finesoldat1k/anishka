import 'package:material_ui/material_ui.dart';

enum HomeTab {
  airing('сейчас', Icons.play_circle_outline_rounded),
  favorites('избранное', Icons.favorite_border_rounded),
  watching('смотрю', Icons.visibility_outlined),
  planned('в планах', Icons.bookmark_border_rounded),
  completed('просмотренно', Icons.check_circle_outline_rounded);

  const HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
