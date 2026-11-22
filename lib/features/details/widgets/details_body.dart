import 'package:material_ui/material_ui.dart';

import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/description.dart';
import 'stills_viewer.dart';
import '../../../ui/widgets/skeleton.dart';

/// Below-hero content: a calm, typographic layout.
///
/// Order is fixed: synopsis first, then genres / studios, then episode stills.
class DetailsBody extends StatefulWidget {
  const DetailsBody({
    super.key,
    required this.anime,
    required this.compact,
    this.loadingStills = false,
  });

  final AnimeWithSources anime;
  final bool compact;
  final bool loadingStills;

  @override
  State<DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends State<DetailsBody> {
  bool _expanded = false;

  ShikimoriAnimeDetails get _details => widget.anime.shikimoriAnime;

  static String _cleanDescription(String raw) => cleanAnimeDescription(raw);

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final details = _details;

    final rawDescription = details.descriptionText;
    final cleanedDescription = _cleanDescription(rawDescription);
    final description = cleanedDescription.isEmpty
        ? 'описание пока не добавили.'
        : cleanedDescription;
    final longDescription = description.length > 460;

    final genres = details.allGenres;
    final studios = details.allStudios;

    final stills = _collectStills(details);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Description(
          text: description,
          long: longDescription,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
          compact: compact,
        ),
        if (genres.isNotEmpty) ...[
          SizedBox(height: compact ? 18 : 22),
          _PlainMetaLine(
            label: 'жанры:',
            value: genres.join(', ').toLowerCase(),
            compact: compact,
          ),
        ],
        if (studios.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          _PlainMetaLine(
            label: 'студия:',
            value: studios.join(', '),
            compact: compact,
          ),
        ],
        if (stills.isNotEmpty || widget.loadingStills) ...[
          SizedBox(height: compact ? 30 : 40),
          _StillsSection(
            stills: stills,
            compact: compact,
            loading: widget.loadingStills,
          ),
        ],
      ],
    );
  }

  List<String> _collectStills(ShikimoriAnimeDetails details) {
    final stills = <String>{};
    for (final screenshot in details.screenshots) {
      if (screenshot.isNotEmpty) stills.add(screenshot);
    }

    for (final source in widget.anime.sources) {
      for (final episode in source.release.episodes) {
        final preview = episode.previewUrl;
        if (preview != null && preview.isNotEmpty) stills.add(preview);
      }
    }

    if (stills.isEmpty) {
      final fallback = details.stillUrl ?? details.metadataBackground;
      if (fallback != null && fallback.isNotEmpty) stills.add(fallback);
    }
    return stills.take(18).toList();
  }
}

class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.long,
    required this.expanded,
    required this.onToggle,
    required this.compact,
  });

  final String text;
  final bool long;
  final bool expanded;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlainMetaLine(
          label: 'описание:',
          value: text,
          compact: compact,
          isDescription: true,
          long: long,
          expanded: expanded,
          onToggle: onToggle,
        ),
      ],
    );
  }
}

class _PlainMetaLine extends StatelessWidget {
  const _PlainMetaLine({
    required this.label,
    required this.value,
    required this.compact,
    this.isDescription = false,
    this.long = false,
    this.expanded = false,
    this.onToggle,
  });

  final String label;
  final String value;
  final bool compact;
  final bool isDescription;
  final bool long;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    if (isDescription) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: compact ? 12 : 13,
                      height: 1.5,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w400,
                      fontSize: compact ? 13.5 : 15,
                      height: 1.68,
                      color: AppColors.textSoft.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              maxLines: long && !expanded ? 6 : null,
              overflow: long && !expanded
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
            ),
          ),
          if (long)
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    expanded ? 'свернуть' : 'читать дальше',
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: compact ? 12 : 13,
              height: 1.5,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: compact ? 12 : 13,
              height: 1.5,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

String _stillsLabel(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  final word = (mod100 >= 11 && mod100 <= 14)
      ? 'кадров'
      : switch (mod10) {
          1 => 'кадр',
          2 || 3 || 4 => 'кадра',
          _ => 'кадров',
        };
  return '$count $word';
}

class _StillsSection extends StatelessWidget {
  const _StillsSection({
    required this.stills,
    required this.compact,
    this.loading = false,
  });

  final List<String> stills;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'кадры из серий',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 14 : 16,
                  letterSpacing: -0.4,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'загружаем кадры...',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          _StillsSkeleton(compact: compact),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'кадры из серий',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w500,
                fontSize: compact ? 14 : 16,
                letterSpacing: -0.4,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          _stillsLabel(stills.length),
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        StillsGallery(stills: stills, compact: compact),
      ],
    );
  }
}

class _StillsSkeleton extends StatelessWidget {
  const _StillsSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 118.0 : 172.0;
    final width = height * 16 / 9;
    final count = compact ? 4 : 5;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return SizedBox(
            width: width,
            child: SkeletonBox(height: height, borderRadius: 12),
          );
        },
      ),
    );
  }
}
