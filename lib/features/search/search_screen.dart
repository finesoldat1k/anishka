import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/shikimori_anime.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/storage/search_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/anime_card.dart';
import '../../ui/widgets/anime_list_tile.dart';
import '../../ui/widgets/app_image.dart';
import '../../ui/widgets/state_views.dart';
import '../../ui/widgets/view_toggle.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _suggestions = [
    'магическая битва',
    'атака титанов',
    'фрирен',
    'человек-бензопила',
    'клинок, рассекающий демонов',
  ];

  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'search');
  Timer? _debounce;
  int _request = 0;

  String _query = '';
  bool _loading = false;
  String? _error;
  List<ShikimoriAnime> _results = const [];
  AnimeViewMode _mode = AnimeViewMode.grid;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _request++;
      setState(() {
        _query = '';
        _loading = false;
        _error = null;
        _results = const [];
      });
      return;
    }

    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 360), () {
      _run(query, ++_request);
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    _run(query, ++_request);
  }

  void _useSuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _focusNode.requestFocus();
    _submit(value);
  }

  void _clear() {
    _debounce?.cancel();
    _request++;
    _controller.clear();
    _focusNode.requestFocus();
    setState(() {
      _query = '';
      _loading = false;
      _error = null;
      _results = const [];
    });
  }

  void _removeHistoryItem(String query) {
    context.read<SearchStore>().history.removeWhere(
      (h) => h.toLowerCase() == query.toLowerCase(),
    );
    context.read<SearchStore>().persistHistory();
    setState(() {});
  }

  Future<void> _run(String query, int token) async {
    final repository = context.read<AnimeRepository>();
    try {
      final results = await repository.searchShikimori(query);
      if (!mounted || token != _request) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
      });
      // Add to history on successful search
      context.read<SearchStore>().addToHistory(query);
    } catch (error) {
      if (!mounted || token != _request) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = userMessage(error);
      });
    }
  }

  void _open(ShikimoriAnime anime) {
    context.read<SearchStore>().addVisited(anime);
    context.push('/anime/shikimori/${anime.id}', extra: anime);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final padding = pagePadding(width);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 12),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: AppIcons.arrowLeft,
                        tooltip: 'назад',
                        onTap: _back,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildSearchField(compact)),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 4, padding, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _query.isEmpty
                              ? 'поиск по каталогу'
                              : _loading
                              ? 'ищем «${_query.toLowerCase()}»'
                              : '${releasesLabel(_results.length)} по запросу «${_query.toLowerCase()}»',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ViewToggle(
                        mode: _mode,
                        onChanged: (mode) => setState(() => _mode = mode),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 0, padding, 0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _content(),
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

  Widget _buildSearchField(bool compact) {
    return FocusableActionDetector(
      onFocusChange: (hasFocus) => setState(() {}),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focusNode.hasFocus
                ? AppColors.planned.withValues(alpha: 0.55)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _focusNode.hasFocus
                  ? AppColors.planned.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.22),
              blurRadius: 26,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              AppIcons.magnifyingGlass,
              size: 20,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.planned,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  color: AppColors.text,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'название аниме',
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 14,
                    color: AppColors.textFaint,
                  ),
                ),
                onChanged: _onChanged,
                onSubmitted: _submit,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
              )
            else if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: 'очистить',
                onPressed: _clear,
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                icon: const Icon(
                  AppIcons.x,
                  size: 17,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final searchStore = context.watch<SearchStore>();

    if (_query.isEmpty) {
      return _SearchStart(
        key: const ValueKey('start'),
        suggestions: _suggestions,
        history: searchStore.history,
        visited: searchStore.visited,
        onSuggestion: _useSuggestion,
        onHistoryTap: _useSuggestion,
        onHistoryRemove: _removeHistoryItem,
        onVisitedTap: (anime) {
          context.push('/anime/shikimori/${anime.id}', extra: anime);
        },
        onClearHistory: searchStore.history.isNotEmpty
            ? () {
                searchStore.clearHistory();
                setState(() {});
              }
            : null,
        onClearVisited: searchStore.visited.isNotEmpty
            ? () {
                searchStore.clearVisited();
                setState(() {});
              }
            : null,
      );
    }
    if (_error != null) {
      return ErrorState(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: () => _run(_query, ++_request),
      );
    }
    if (_loading) {
      return _mode == AnimeViewMode.grid
          ? const _SearchGridSkeleton(key: ValueKey('loading-grid'))
          : const _SearchListSkeleton(key: ValueKey('loading-list'));
    }
    if (_results.isEmpty) {
      return EmptyState(
        key: const ValueKey('empty'),
        icon: AppIcons.magnifyingGlassMinus,
        title: 'ничего не нашлось',
        message: 'попробуйте другое название или проверьте раскладку.',
        actionLabel: 'очистить поиск',
        onAction: _clear,
      );
    }

    return CustomScrollView(
      key: ValueKey('results-${_mode.name}'),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        if (_mode == AnimeViewMode.grid)
          SliverAnimeGrid(items: _results, onTap: (item) => _open(item))
        else
          SliverAnimeList(items: _results, onTap: (item) => _open(item)),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _SearchStart extends StatelessWidget {
  const _SearchStart({
    super.key,
    required this.suggestions,
    required this.history,
    required this.visited,
    required this.onSuggestion,
    required this.onHistoryTap,
    required this.onHistoryRemove,
    required this.onVisitedTap,
    this.onClearHistory,
    this.onClearVisited,
  });

  final List<String> suggestions;
  final List<String> history;
  final List<VisitedAnime> visited;
  final ValueChanged<String> onSuggestion;
  final ValueChanged<String> onHistoryTap;
  final ValueChanged<String> onHistoryRemove;
  final ValueChanged<VisitedAnime> onVisitedTap;
  final VoidCallback? onClearHistory;
  final VoidCallback? onClearVisited;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.planned.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppColors.planned.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  AppIcons.globe,
                  size: 28,
                  color: AppColors.planned,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'найдите своё следующее аниме',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  letterSpacing: -0.6,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'каталог shikimori, русские названия и постеры',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            if (history.isNotEmpty || visited.isNotEmpty) ...[
              const SizedBox(height: 34),
              if (history.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'история поиска',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const Spacer(),
                    if (onClearHistory != null)
                      TextButton(
                        onPressed: onClearHistory,
                        child: Text(
                          'очистить',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11,
                            color: AppColors.planned,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in history)
                      _HistoryChip(
                        label: item,
                        onTap: () => onHistoryTap(item),
                        onRemove: () => onHistoryRemove(item),
                      ),
                  ],
                ),
              ],
            if (visited.isNotEmpty) ...[
              if (history.isNotEmpty) const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'недавно посещённые',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: AppColors.textFaint,
                    ),
                  ),
                  const Spacer(),
                  if (onClearVisited != null)
                    TextButton(
                      onPressed: onClearVisited,
                      child: Text(
                        'очистить',
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 11,
                          color: AppColors.planned,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in visited)
                    _VisitedChip(
                      anime: item,
                      onTap: () => onVisitedTap(item),
                    ),
                ],
              ),
            ],
          ]
        else ...[
          const SizedBox(height: 34),
          const Text(
            'попробуйте',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.6,
              color: AppColors.textFaint,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in suggestions)
                _SuggestionChip(
                  label: suggestion,
                  onTap: () => onSuggestion(suggestion),
                ),
            ],
          ),
        ],
      ],
    ), 
  );
}
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    AppIcons.x,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitedChip extends StatelessWidget {
  const _VisitedChip({
    required this.anime,
    required this.onTap,
  });

  final VisitedAnime anime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (anime.posterUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(
                  url: anime.posterUrl!,
                  width: 100,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(AppIcons.filmStrip, color: AppColors.textMuted),
              ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: AppColors.text,
              ),
            ),
            if (anime.year != null) ...[
              const SizedBox(height: 2),
              Text(
                '${anime.year}',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              color: AppColors.textSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchGridSkeleton extends StatelessWidget {
  const _SearchGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      slivers: [SliverAnimeGridSkeleton(count: 12)],
    );
  }
}

class _SearchListSkeleton extends StatelessWidget {
  const _SearchListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      slivers: [SliverAnimeListSkeleton(count: 8)],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.8),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: AppColors.textSoft),
          ),
        ),
      ),
    );
  }
}
