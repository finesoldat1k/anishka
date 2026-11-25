import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/shikimori_anime.dart';
import '../../../core/repository/unified_repository.dart';
import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/anime_list_tile.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../ui/widgets/skeleton.dart';
import '../../../ui/widgets/state_views.dart';

class OngoingView extends StatefulWidget {
  const OngoingView({super.key, required this.onOpen, required this.grid});

  final void Function(ShikimoriAnime anime) onOpen;
  final bool grid;

  @override
  State<OngoingView> createState() => _OngoingViewState();
}

class _OngoingViewState extends State<OngoingView> {
  static const int _pageSize = 30;

  late final UnifiedRepository _repository;
  final ScrollController _scrollController = ScrollController();
  final List<ShikimoriAnime> _items = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AppServices>().repository;
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 640) return;
    _loadMore();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await _repository.getPopular(
        refresh: refresh,
        limit: _pageSize,
        page: 1,
        status: 'ongoing',
        order: 'popularity',
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _page = 1;
        _hasMore = list.length >= _pageSize;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_items.isEmpty) {
        setState(() => _error = userMessage(error));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _refreshing || !_hasMore) return;
    setState(() => _loadingMore = true);

    final nextPage = _page + 1;
    try {
      final list = await _repository.getPopular(
        limit: _pageSize,
        page: nextPage,
        status: 'ongoing',
        order: 'popularity',
      );
      if (!mounted) return;
      final known = _items.map((anime) => anime.id).toSet();
      final fresh = list.where((anime) => known.add(anime.id)).toList();
      setState(() {
        _page = nextPage;
        _hasMore = list.length >= _pageSize && fresh.isNotEmpty;
        _items.addAll(fresh);
      });
    } catch (error) {
      if (!mounted) return;
      // Stop retrying on every scroll tick; pull-to-refresh restarts paging.
      setState(() => _hasMore = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessage(error))));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const _OngoingSkeleton();
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: ErrorState(message: _error!, onRetry: () => _load()),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: EmptyState(
          icon: AppIcons.playCircle,
          title: 'в эфире пока тихо',
          message: 'онгоинги появятся здесь, как только их добавят в каталог.',
          actionLabel: 'обновить',
          onAction: () => _load(refresh: true),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          color: AppColors.accentBright,
          backgroundColor: AppColors.surfaceHigh,
          displacement: 20,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 18),
                  child: SectionHeader(
                    title: 'сейчас в эфире',
                    subtitle:
                        '${releasesLabel(_items.length)} · данные с shikimori',
                    compact: compact,
                    trailing: _RefreshButton(
                      busy: _refreshing,
                      onTap: () => _load(refresh: true),
                    ),
                  ),
                ),
              ),
              if (widget.grid)
                SliverAnimeGrid(items: _items, onTap: widget.onOpen)
              else
                SliverAnimeList(items: _items, onTap: widget.onOpen),
              if (_loadingMore)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 18),
                  sliver: widget.grid
                      ? SliverAnimeGridSkeleton(count: compact ? 3 : 6)
                      : const SliverAnimeListSkeleton(count: 3),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'обновить',
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.8),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.arrowClockwise, size: 18),
          ),
        ),
      ),
    );
  }
}

class _OngoingSkeleton extends StatelessWidget {
  const _OngoingSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 6, bottom: 18),
                child: Row(
                  children: [
                    SkeletonBox(width: 3, height: 22, borderRadius: 99),
                    SizedBox(width: 11),
                    SkeletonBox(width: 190, height: 20, borderRadius: 6),
                  ],
                ),
              ),
            ),
            SliverAnimeGridSkeleton(count: compact ? 6 : 12),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      },
    );
  }
}
