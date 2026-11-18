import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_release.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/storage/library_store.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/layout.dart';
import 'home_tab.dart';
import 'widgets/home_header.dart';
import 'widgets/home_tabs.dart';
import 'widgets/library_view.dart';
import 'widgets/ongoing_view.dart';
import 'widgets/search_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  int _searchRequest = 0;

  HomeTab _tab = HomeTab.airing;
  String _query = '';
  List<dynamic> _results = const [];
  bool _searchLoading = false;
  String? _searchError;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _searchRequest++;
      setState(() {
        _query = '';
        _results = const [];
        _searchLoading = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _query = query;
      _searchLoading = true;
      _searchError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 380), () {
      _runSearch(query);
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _searchLoading = true;
      _searchError = null;
    });
    _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchRequest;
    final repository = context.read<AnimeRepository>();
    try {
      final results = await repository.searchShikimori(query);
      if (!mounted || token != _searchRequest) return;
      setState(() {
        _results = results;
        _searchLoading = false;
        _searchError = null;
      });
    } catch (error) {
      if (!mounted || token != _searchRequest) return;
      setState(() {
        _results = const [];
        _searchLoading = false;
        _searchError = userMessage(error);
      });
    }
  }

  void _clearSearch({bool keepFocus = false}) {
    _debounce?.cancel();
    _searchRequest++;
    _searchController.clear();
    if (!keepFocus) _searchFocus.unfocus();
    setState(() {
      _query = '';
      _results = const [];
      _searchLoading = false;
      _searchError = null;
    });
  }

  void _selectTab(HomeTab tab) {
    if (_query.isNotEmpty) _clearSearch(keepFocus: false);
    setState(() => _tab = tab);
  }

  void _openAnime(dynamic anime) {
    if (anime is AnimeRelease) {
      context.push('/anime/${anime.id}');
    } else if (anime is ShikimoriAnime) {
      // Navigate to details which will fetch sources
      context.push('/anime/shikimori/${anime.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final width = MediaQuery.sizeOf(context).width;
    final padding = pagePadding(width);

    final counts = <HomeTab, int>{
      HomeTab.favorites: library.countFavorites(),
      HomeTab.watching: library.countStatus(CollectionStatus.watching),
      HomeTab.planned: library.countStatus(CollectionStatus.planned),
      HomeTab.completed: library.countStatus(CollectionStatus.completed),
    };

    final Widget content;
    if (_query.isNotEmpty) {
      content = SearchView(
        key: const ValueKey('search'),
        query: _query,
        results: _results,
        loading: _searchLoading,
        error: _searchError,
        onRetry: () => _runSearch(_query),
        onOpen: _openAnime,
        onClear: _clearSearch,
      );
    } else {
      content = switch (_tab) {
        HomeTab.airing => OngoingView(
          key: const ValueKey('airing'),
          onOpen: _openAnime,
        ),
        HomeTab.favorites => LibraryView(
          key: const ValueKey('favorites'),
          tab: HomeTab.favorites,
          entries: library.favorites(),
          onOpen: _openAnime,
          onBrowse: () => _selectTab(HomeTab.airing),
        ),
        HomeTab.watching => LibraryView(
          key: const ValueKey('watching'),
          tab: HomeTab.watching,
          entries: library.byStatus(CollectionStatus.watching),
          onOpen: _openAnime,
          onBrowse: () => _selectTab(HomeTab.airing),
        ),
        HomeTab.planned => LibraryView(
          key: const ValueKey('planned'),
          tab: HomeTab.planned,
          entries: library.byStatus(CollectionStatus.planned),
          onOpen: _openAnime,
          onBrowse: () => _selectTab(HomeTab.airing),
        ),
        HomeTab.completed => LibraryView(
          key: const ValueKey('completed'),
          tab: HomeTab.completed,
          entries: library.byStatus(CollectionStatus.completed),
          onOpen: _openAnime,
          onBrowse: () => _selectTab(HomeTab.airing),
        ),
      };
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 18, padding, 10),
                  child: HomeHeader(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onQueryChanged,
                    onSubmitted: _onSubmitted,
                    onClear: _clearSearch,
                    loading: _searchLoading,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: HomeTabs(
                    selected: _tab,
                    onSelected: _selectTab,
                    counts: counts,
                  ),
                ),
                const SizedBox(height: 16),
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
