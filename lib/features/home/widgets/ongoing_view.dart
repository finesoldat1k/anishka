import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/repository/anime_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/gradient_button.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../ui/widgets/skeleton.dart';
import '../../../ui/widgets/source_note.dart';
import '../../../ui/widgets/state_views.dart';
import 'featured_hero.dart';

class OngoingView extends StatefulWidget {
  const OngoingView({super.key, required this.onOpen});

  final void Function(dynamic anime) onOpen;

  @override
  State<OngoingView> createState() => _OngoingViewState();
}

class _OngoingViewState extends State<OngoingView> {
  late final AnimeRepository _repository;
  final List<dynamic> _items = [];
  bool _loading = true;
  bool _refreshing = false;
  final bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AnimeRepository>();
    _load();
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
        limit: 24,
        status: 'ongoing',
        order: 'popularity',
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _page = 1;
        _totalPages = 1; // Shikimori doesn't paginate the same way
        _total = list.length;
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
    // Shikimori doesn't have the same pagination for popular/ongoing
    // Could implement offset-based if needed
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
          icon: Icons.play_circle_outline_rounded,
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 30),
                  child: FeaturedHero(
                    items: _items.take(3).toList(),
                    onOpen: widget.onOpen,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'сейчас в эфире',
                  subtitle: _total > 0
                      ? '${releasesLabel(_total)} · данные с shikimori'
                      : 'текущие онгоинги',
                  compact: compact,
                  trailing: _RefreshButton(
                    busy: _refreshing,
                    onTap: () => _load(refresh: true),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverAnimeGrid(items: _items, onTap: widget.onOpen),
              if (_page < _totalPages)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Center(
                      child: GradientButton(
                        label: _loadingMore ? 'загружаем...' : 'показать ещё',
                        icon: _loadingMore
                            ? Icons.hourglass_top_rounded
                            : Icons.expand_more_rounded,
                        ghost: true,
                        onTap: _loadingMore ? null : _loadMore,
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SourceNote()),
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
                : const Icon(Icons.refresh_rounded, size: 18),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 30),
                child: SkeletonBox(
                  height: compact ? 360 : 430,
                  borderRadius: 24,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    SkeletonBox(width: 3, height: 22, borderRadius: 99),
                    SizedBox(width: 11),
                    SkeletonBox(width: 190, height: 20, borderRadius: 6),
                  ],
                ),
              ),
            ),
            const SliverAnimeGridSkeleton(count: 12),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        );
      },
    );
  }
}
