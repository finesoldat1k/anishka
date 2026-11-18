import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/anime_card.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../ui/widgets/source_note.dart';
import '../../../ui/widgets/state_views.dart';

class SearchView extends StatelessWidget {
  const SearchView({
    super.key,
    required this.query,
    required this.results,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onOpen,
    required this.onClear,
  });

  final String query;
  final List<dynamic> results;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final void Function(dynamic anime) onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: SectionHeader(
              title: 'поиск',
              subtitle: 'по запросу «${query.toLowerCase()}»',
            ),
          ),
        ),
        if (loading)
          const SliverAnimeGridSkeleton(count: 10)
        else if (error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(message: error!, onRetry: onRetry),
          )
        else if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'ничего не нашлось',
              message: 'попробуйте другое название или проверьте раскладку.',
              actionLabel: 'очистить поиск',
              onAction: onClear,
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '${releasesLabel(results.length)} по вашему запросу',
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          SliverAnimeGrid(items: results, onTap: onOpen),
          const SliverToBoxAdapter(child: SourceNote()),
        ],
      ],
    );
  }
}
