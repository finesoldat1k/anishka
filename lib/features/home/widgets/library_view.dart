import 'package:material_ui/material_ui.dart';

import '../../../core/storage/library_store.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/anime_list_tile.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../ui/widgets/state_views.dart';
import '../home_tab.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.tab,
    required this.entries,
    required this.onOpen,
    required this.onBrowse,
    required this.grid,
  });

  final HomeTab tab;
  final List<LibraryEntry> entries;
  final void Function(dynamic anime) onOpen;
  final VoidCallback onBrowse;
  final bool grid;

  EmptyState _empty() {
    final (icon, title, message) = switch (tab) {
      HomeTab.favorites => (
        Icons.favorite_border_rounded,
        'в избранном пока пусто',
        'нажмите на сердце на странице аниме — и оно появится здесь.',
      ),
      HomeTab.watching => (
        Icons.visibility_outlined,
        'вы ничего не смотрите',
        'поставьте закладку «смотрю», чтобы вернуться к сериалу в один клик.',
      ),
      HomeTab.planned => (
        Icons.bookmark_border_rounded,
        'в планах пока пусто',
        'добавляйте сюда то, что хочется посмотреть чуть позже.',
      ),
      HomeTab.completed => (
        Icons.check_circle_outline_rounded,
        'просмотренного пока нет',
        'завершённые тайтлы будут храниться здесь.',
      ),
      HomeTab.airing => (
        Icons.play_circle_outline_rounded,
        'ничего нет',
        'перейдите на главную, чтобы выбрать аниме.',
      ),
    };

    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      actionLabel: 'смотреть онгоинги',
      onAction: onBrowse,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = entries.map((entry) => entry.anime).toList();
    final count = entries.length;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 18),
            child: SectionHeader(
              title: tab.label,
              subtitle: count == 0
                  ? 'здесь пока пусто'
                  : '${releasesLabel(count)} в вашей библиотеке',
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _empty())
        else if (grid)
          SliverAnimeGrid(items: items, onTap: onOpen)
        else
          SliverAnimeList(items: items, onTap: onOpen),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}
