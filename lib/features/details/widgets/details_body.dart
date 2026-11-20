import 'package:material_ui/material_ui.dart';

import '../../../core/models/anime_episode.dart';
import '../../../core/models/anime_release.dart';
import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'stills_viewer.dart';
import '../../../ui/widgets/skeleton.dart';

/// Below-hero content: a calm, typographic layout.
///
/// Order is fixed and intentionally plain: the synopsis first, then
/// `описание:` / `жанры:` / `студия:` as bare text lines, then episode stills. Related
/// releases follow outside this widget. No chips, cards or decorative
/// containers compete with the hero.
class DetailsBody extends StatefulWidget {
  /// Legacy AniLibria-only constructor.
  const DetailsBody.legacy({
    super.key,
    required this.release,
    required this.compact,
  }) : animeWithSources = null,
       loadingStills = false,
       loadingRelated = false,
       _legacy = true;

  /// New Shikimori-based constructor with multiple sources.
  const DetailsBody.sources({
    super.key,
    required this.animeWithSources,
    required this.compact,
    this.loadingStills = false,
    this.loadingRelated = false,
  }) : release = null,
       _legacy = false;

  final AnimeRelease? release;
  final AnimeWithSources? animeWithSources;
  final bool compact;
  final bool loadingStills;
  final bool loadingRelated;
  final bool _legacy;

  @override
  State<DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends State<DetailsBody> {
  bool _expanded = false;

  AnimeRelease? get _release => widget._legacy
      ? widget.release
      : widget.animeWithSources?.defaultSource?.release;

  ShikimoriAnimeDetails? get _shikimoriAnime =>
      widget.animeWithSources?.shikimoriAnime;

  static String _cleanDescription(String raw) {
    // Remove Shikimori/Anilist markup tags like [character=123]Name[/character]
    // [anime=123]Title[/anime], [manga=123]Title[/manga], [person=123]Name[/person]
    // [url=...]text[/url], [b]text[/b], [i]text[/i], [u]text[/u], [spoiler]text[/spoiler]
    String cleaned = raw
        .replaceAllMapped(
          RegExp(r'\[(character|anime|manga|person|url|b|i|u|spoiler|quote|code|align|center|left|right|size|color|font|email|img|video|audio)[^\]]*\]'),
          (match) => '',
        )
        .replaceAllMapped(
          RegExp(r'\[/(character|anime|manga|person|url|b|i|u|spoiler|quote|code|align|center|left|right|size|color|font|email|img|video|audio)\]'),
          (match) => '',
        )
        // Remove any remaining [tag=value] or [/tag] patterns
        .replaceAllMapped(RegExp(r'\[/?[a-z]+(?:=[^\]]*)?\]'), (match) => '')
        // Clean up multiple spaces and newlines
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final release = _release;
    final details = _shikimoriAnime;

    final rawDescription = widget._legacy
        ? (release?.displayDescription ?? '')
        : (details?.descriptionText ?? '');
    final cleanedDescription = _cleanDescription(rawDescription);
    final description = cleanedDescription.isEmpty
        ? 'описание пока не добавили.'
        : cleanedDescription;
    final longDescription = description.length > 460;

    final genres = widget._legacy
        ? (release?.displayGenres ?? const <String>[])
        : (details?.allGenres ?? const <String>[]);
    final studios = widget._legacy
        ? const <String>[]
        : (details?.allStudios ?? const <String>[]);

    final stills = _collectStills(release, details);

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

    final releases = <AnimeRelease>[
      ?release,
      ...?widget.animeWithSources?.sources.map((source) => source.release),
    ];
    for (final item in releases) {
      final episodes = item.episodes;
      for (final AnimeEpisode episode in episodes) {
        final preview = episode.previewUrl;
        if (preview != null && preview.isNotEmpty) stills.add(preview);
      }
    }

    if (stills.isEmpty) {
      final fallback = widget._legacy
          ? release?.backgroundUrl
          : (details?.stillUrl ?? details?.metadataBackground);
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

/// `описание:` / `жанры: …` / `студия: …` — label and value both plain text.
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

class _StillsSection extends StatelessWidget {
  const _StillsSection({required this.stills, required this.compact, this.loading = false});

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
            child: SkeletonBox(
              height: height,
              borderRadius: 12,
            ),
          );
        },
      ),
    );
  }
}
