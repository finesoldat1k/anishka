import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/repository/anime_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/anime_list_tile.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../ui/widgets/skeleton.dart';
import '../../../ui/widgets/state_views.dart';

class OngoingView extends StatefulWidget {
  const OngoingView({
    super.key,
    required this.onOpen,
    required this.grid,
  });

  final void Function(dynamic anime) onOpen;
  final bool grid;

  @override
  State<OngoingView> createState() => _OngoingViewState();
}

class _OngoingViewState extends State<OngoingView> {
  late final AnimeRepository _repository;
  final List<dynamic> _items = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

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
        limit: 42,
        status: 'ongoing',
        order: 'popularity',
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
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
