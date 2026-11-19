import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_release.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/anime_card.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/state_views.dart';
import 'widgets/subpage_header.dart';

/// Arguments passed to [RelatedScreen] through GoRouter `extra`.
class RelatedArgs {
  const RelatedArgs({required this.items, this.title});

  final List<dynamic> items;
  final String? title;
}

/// Full list of related releases, opened from the details rail.
class RelatedScreen extends StatefulWidget {
  const RelatedScreen({
    super.key,
    this.items,
    this.shikimoriId,
    this.title,
  });

  final List<dynamic>? items;
  final int? shikimoriId;
  final String? title;

  @override
  State<RelatedScreen> createState() => _RelatedScreenState();
}

class _RelatedScreenState extends State<RelatedScreen> {
  late final AnimeRepository _repository;
  List<dynamic> _items = const [];
  bool _loading = false;
  String? _error;
  String? _animeTitle;

  @override
  void initState() {
    super.initState();
    _repository = context.read<AnimeRepository>();
    _items = widget.items ?? const [];
    _animeTitle = widget.title;
    if (_items.isEmpty && widget.shikimoriId != null) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final id = widget.shikimoriId;
    if (id == null || id <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final anime = await _repository.getAnimeWithSources(
        id,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _items = anime.related;
        _animeTitle ??= anime.displayTitle;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _open(dynamic anime) {
    if (anime is AnimeRelease) {
      context.push('/anime/${anime.id}');
    } else if (anime is ShikimoriAnime) {
      context.push('/anime/shikimori/${anime.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final padding = pagePadding(width);
    final hasItems = _items.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          color: AppColors.accentBright,
          backgroundColor: AppColors.surfaceHigh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: SubpageHeader(
                      eyebrow: 'франшиза',
                      title: _animeTitle ?? 'связанные релизы',
                      subtitle: hasItems
                          ? '${releasesLabel(_items.length)} · вся история по порядку'
                          : 'связанные релизы',
                      onBack: _back,
                      compact: compact,
                    ),
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: ErrorState(
                    message: _error!,
                    compact: true,
                    onRetry: () => _load(refresh: true),
                  ),
                )
              else if (_loading && !hasItems)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 186,
                          mainAxisExtent: 282,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const AnimeCardSkeleton(),
                      childCount: 8,
                    ),
                  ),
                )
              else if (!hasItems)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.link_off_rounded,
                    title: 'связей нет',
                    message:
                        'в каталоге shikimori пока нет связанных релизов '
                        'для этого тайтла.',
                    compact: true,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 186,
                          mainAxisExtent: 282,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final anime = _items[index];
                        return AnimeCard(
                          anime: anime,
                          dense: true,
                          onTap: () => _open(anime),
                        );
                      },
                      childCount: _items.length,
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
