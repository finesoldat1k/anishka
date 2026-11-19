import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_release.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/view_toggle.dart';
import 'home_tab.dart';
import 'widgets/home_header.dart';
import 'widgets/home_tabs.dart';
import 'widgets/library_view.dart';
import 'widgets/ongoing_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.airing;
  AnimeViewMode _mode = AnimeViewMode.grid;

  void _selectTab(HomeTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  void _openAnime(dynamic anime) {
    if (anime is AnimeRelease) {
      context.push('/anime/${anime.id}');
    } else if (anime is ShikimoriAnime) {
      context.push('/anime/shikimori/${anime.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final padding = pagePadding(width);

    final counts = <HomeTab, int>{
      HomeTab.favorites: library.countFavorites(),
      HomeTab.watching: library.countStatus(CollectionStatus.watching),
      HomeTab.planned: library.countStatus(CollectionStatus.planned),
      HomeTab.completed: library.countStatus(CollectionStatus.completed),
    };

    final content = switch (_tab) {
      HomeTab.airing => OngoingView(
        key: const ValueKey('airing'),
        onOpen: _openAnime,
        grid: _mode == AnimeViewMode.grid,
      ),
      HomeTab.favorites => LibraryView(
        key: const ValueKey('favorites'),
        tab: HomeTab.favorites,
        entries: library.favorites(),
        onOpen: _openAnime,
        onBrowse: () => _selectTab(HomeTab.airing),
        grid: _mode == AnimeViewMode.grid,
      ),
      HomeTab.watching => LibraryView(
        key: const ValueKey('watching'),
        tab: HomeTab.watching,
        entries: library.byStatus(CollectionStatus.watching),
        onOpen: _openAnime,
        onBrowse: () => _selectTab(HomeTab.airing),
        grid: _mode == AnimeViewMode.grid,
      ),
      HomeTab.planned => LibraryView(
        key: const ValueKey('planned'),
        tab: HomeTab.planned,
        entries: library.byStatus(CollectionStatus.planned),
        onOpen: _openAnime,
        onBrowse: () => _selectTab(HomeTab.airing),
        grid: _mode == AnimeViewMode.grid,
      ),
      HomeTab.completed => LibraryView(
        key: const ValueKey('completed'),
        tab: HomeTab.completed,
        entries: library.byStatus(CollectionStatus.completed),
        onOpen: _openAnime,
        onBrowse: () => _selectTab(HomeTab.airing),
        grid: _mode == AnimeViewMode.grid,
      ),
    };

    final viewToggle = ViewToggle(
      mode: _mode,
      onChanged: (mode) => setState(() => _mode = mode),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 12),
                  child: HomeHeader(
                    compact: compact,
                    onSearchTap: () => context.push('/search'),
                    onAboutTap: () => context.push('/about'),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HomeTabs(
                              selected: _tab,
                              onSelected: _selectTab,
                              counts: counts,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const SizedBox(width: 2),
                                const Text(
                                  'вид',
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 10.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                                const Spacer(),
                                viewToggle,
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: HomeTabs(
                                selected: _tab,
                                onSelected: _selectTab,
                                counts: counts,
                              ),
                            ),
                            const SizedBox(width: 10),
                            viewToggle,
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 230),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.015),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
