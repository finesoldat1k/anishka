import 'package:material_ui/material_ui.dart';

import '../../../core/models/anime_episode.dart';
import '../../../core/models/anime_release.dart';
import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/widgets/section_header.dart';
import 'stills_viewer.dart';

class DetailsBody extends StatefulWidget {
  /// Legacy AniLibria-only constructor.
  const DetailsBody.legacy({
    super.key,
    required this.release,
    required this.compact,
  }) : animeWithSources = null,
       _legacy = true;

  /// New Shikimori-based constructor with multiple sources.
  const DetailsBody.sources({
    super.key,
    required this.animeWithSources,
    required this.compact,
  }) : release = null,
       _legacy = false;

  final AnimeRelease? release;
  final AnimeWithSources? animeWithSources;
  final bool compact;
  final bool _legacy;

  @override
  State<DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends State<DetailsBody> {
  bool _expanded = false;

  AnimeRelease? get _release =>
      widget._legacy ? widget.release : widget.animeWithSources?.defaultSource?.release;

  ShikimoriAnimeDetails? get _shikimoriAnime =>
      widget.animeWithSources?.shikimoriAnime;

  @override
  Widget build(BuildContext context) {
    final release = _release;
    final shikimoriAnime = _shikimoriAnime;
    final compact = widget.compact;

    final description = widget._legacy
        ? (release?.displayDescription ?? '')
        : (shikimoriAnime?.descriptionText.trim().isNotEmpty == true
              ? shikimoriAnime!.descriptionText
              : 'описание пока не добавили.');
    final longDescription = description.length > 420;

    final genres = (widget._legacy && release != null)
        ? (release.displayGenres)
        : (shikimoriAnime?.allGenres ?? <String>[]);
    final studios = (!widget._legacy)
        ? (shikimoriAnime?.allStudios ?? <String>[])
        : const <String>[];
    final year = widget._legacy ? release?.year : shikimoriAnime?.year;
    final kind = widget._legacy ? release?.type : shikimoriAnime?.kindLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Description block - clean text only
        _DescriptionBlock(
          description: description,
          longDescription: longDescription,
          expanded: _expanded,
          onExpandToggle: () => setState(() => _expanded = !_expanded),
          compact: compact,
        ),

        // Meta info: genres, studio, year, type
        if (genres.isNotEmpty || studios.isNotEmpty || year != null || kind != null)
          _MetaBlock(
            genres: genres,
            studios: studios,
            year: year,
            kind: kind,
            compact: compact,
          ),

        const SizedBox(height: 16),

        // Stills from episodes
        _buildStillsBlock(release, shikimoriAnime, compact),
      ],
    );
  }

  Widget _buildStillsBlock(
    AnimeRelease? release,
    ShikimoriAnimeDetails? details,
    bool compact,
  ) {
    final stills = _collectStills(release, details);

    if (stills.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 24),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.planned.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.planned.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 18,
                color: AppColors.planned,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Text(
                'источники пока не отдали кадры для этого тайтла.',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _SectionBlock(
      icon: Icons.photo_library_rounded,
      title: 'кадры из серий',
      subtitle: '${stills.length} кадров · нажмите, чтобы увеличить',
      compact: compact,
      child: StillsGallery(stills: stills, compact: compact),
    );
  }

  List<String> _collectStills(
    AnimeRelease? release,
    ShikimoriAnimeDetails? details,
  ) {
    final stills = <String>{};
    if (details != null) {
      for (final screenshot in details.screenshots) {
        if (screenshot.isNotEmpty) stills.add(screenshot);
      }
    }
    final episodes = release?.episodes ?? const <AnimeEpisode>[];
    for (final episode in episodes) {
      final preview = episode.previewUrl;
      if (preview != null && preview.isNotEmpty) stills.add(preview);
    }
    if (stills.isEmpty) {
      final fallback = widget._legacy
          ? release?.backgroundUrl
          : details?.stillUrl;
      if (fallback != null && fallback.isNotEmpty) stills.add(fallback);
    }
    return stills.take(18).toList();
  }
}

class _DescriptionBlock extends StatelessWidget {
  const _DescriptionBlock({
    required this.description,
    required this.longDescription,
    required this.expanded,
    required this.onExpandToggle,
    required this.compact,
  });

  final String description;
  final bool longDescription;
  final bool expanded;
  final VoidCallback onExpandToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.planned.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.planned.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(Icons.text_fields_rounded, size: 17, color: AppColors.planned),
              ),
              const SizedBox(width: 12),
              Text(
                'описание',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 15 : 17,
                  letterSpacing: -0.4,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),

          // Description text
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              description,
              maxLines: longDescription && !expanded ? 6 : null,
              overflow: longDescription && !expanded
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontWeight: FontWeight.w400,
                fontSize: compact ? 12.5 : 13.5,
                height: 1.62,
                color: AppColors.textSoft,
              ),
            ),
          ),
          if (longDescription)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: onExpandToggle,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.planned,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(expanded ? 'свернуть' : 'читать дальше'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.genres,
    required this.studios,
    required this.year,
    required this.kind,
    required this.compact,
  });

  final List<String> genres;
  final List<String> studios;
  final int? year;
  final String? kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (genres.isNotEmpty) ...[
            _MetaRow(
              icon: Icons.local_offer_rounded,
              label: 'жанры',
              value: genres.join(', '),
              compact: compact,
            ),
            const SizedBox(height: 10),
          ],
          if (studios.isNotEmpty) ...[
            _MetaRow(
              icon: Icons.business_rounded,
              label: 'студия',
              value: studios.join(', '),
              compact: compact,
            ),
            const SizedBox(height: 10),
          ],
          if (year != null) ...[
            _MetaRow(
              icon: Icons.calendar_month_rounded,
              label: 'год',
              value: year.toString(),
              compact: compact,
            ),
            const SizedBox(height: 10),
          ],
          if (kind != null && kind!.isNotEmpty) ...[
            _MetaRow(
              icon: Icons.tv_rounded,
              label: 'тип',
              value: kind!.toLowerCase(),
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: compact ? 15 : 17,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: compact ? 12 : 13,
            color: AppColors.textMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: compact ? 12 : 13,
              color: AppColors.textSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.icon,
    required this.title,
    required this.child,
    required this.compact,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.planned.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.planned.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 17, color: AppColors.planned),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toLowerCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 15 : 17,
                        letterSpacing: -0.4,
                        color: AppColors.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!.toLowerCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          child,
        ],
      ),
    );
  }
}