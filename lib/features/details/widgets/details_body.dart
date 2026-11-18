import 'package:material_ui/material_ui.dart';

import '../../../core/models/anime_release.dart';
import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/app_image.dart';
import '../../../ui/widgets/info_chip.dart';
import '../../../ui/widgets/section_header.dart';

class DetailsBody extends StatefulWidget {
  /// Legacy AniLibria-only constructor.
  const DetailsBody.legacy({super.key, required this.release, required this.compact})
      : animeWithSources = null,
        _legacy = true;

  /// New Shikimori-based constructor with multiple sources.
  const DetailsBody.sources({super.key, required this.animeWithSources, required this.compact})
      : release = null,
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

  AnimeRelease? get _release => widget._legacy ? widget.release : widget.animeWithSources?.defaultSource?.release;

  ShikimoriAnimeDetails? get _shikimoriAnime => widget.animeWithSources?.shikimoriAnime;

  @override
  Widget build(BuildContext context) {
    final release = _release;
    final shikimoriAnime = _shikimoriAnime;
    final compact = widget.compact;

    final description = widget._legacy
        ? (release?.displayDescription ?? '')
        : (shikimoriAnime?.description ?? 'описание пока не добавили.');
    final longDescription = description.length > 420;

    final posterUrl = widget._legacy ? release?.posterUrl : shikimoriAnime?.posterUrl;
    final poster = Container(
      width: compact ? 124 : 218,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.13),
            blurRadius: 55,
            spreadRadius: 5,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: AppImage(
          url: posterUrl,
          borderRadius: BorderRadius.circular(18),
          memCacheWidth: 500,
        ),
      ),
    );

    final facts = <Widget>[
      if ((widget._legacy && release?.year != null) || (!widget._legacy && shikimoriAnime?.year != null))
        InfoChip(
          label: 'год · ${widget._legacy ? release?.year : shikimoriAnime?.year}',
          icon: Icons.calendar_today_rounded,
          dense: true,
        ),
      if ((widget._legacy && release?.type != null) || (!widget._legacy && shikimoriAnime?.kind != null))
        InfoChip(
          label: lc(widget._legacy ? (release?.type ?? '') : (shikimoriAnime?.kindLabel ?? '')),
          icon: Icons.tv_rounded,
          dense: true,
        ),
      if ((widget._legacy && release?.season != null) || (!widget._legacy && shikimoriAnime?.airedOn != null))
        InfoChip(
          label: lc(widget._legacy ? (release?.season ?? '') : (shikimoriAnime?.airedOn?.substring(0, 4) ?? '')),
          icon: Icons.wb_sunny_outlined,
          dense: true,
        ),
      if ((widget._legacy && release?.episodeCount != null) || (!widget._legacy && shikimoriAnime?.episodeCount != null))
        InfoChip(
          label: episodesLabel(widget._legacy ? (release?.episodeCount ?? 0) : (shikimoriAnime?.episodeCount ?? 0)),
          icon: Icons.video_collection_outlined,
          dense: true,
        ),
      InfoChip(
        label: widget._legacy ? (release?.statusLabel ?? '') : (shikimoriAnime?.statusLabel ?? ''),
        icon: Icons.sensors_rounded,
        dense: true,
        accent: widget._legacy ? (release?.isOngoing ?? false) : (shikimoriAnime?.isOngoing ?? false),
      ),
      if ((widget._legacy && release?.ageRating != null) || (!widget._legacy && shikimoriAnime?.rating != null))
        InfoChip(
          label: widget._legacy ? (release?.ageRating ?? '') : (shikimoriAnime?.rating ?? ''),
          dense: true,
        ),
    ];

    final genres = (widget._legacy && release != null)
        ? (release.displayGenres)
        : (shikimoriAnime?.genres?.map((g) => g.russian).toList() ?? <String>[]);
    final cast = widget._legacy
        ? (release?.voiceActors ?? <ReleaseMember>[])
        : (shikimoriAnime?.studios?.map((s) => s.name).toList() ?? <String>[]);

    final descriptionBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'описание', compact: true),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Text(
            description,
            maxLines: longDescription && !_expanded ? 6 : null,
            overflow: longDescription && !_expanded
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
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentBright,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_expanded ? 'свернуть' : 'читать дальше'),
            ),
          ),
        const SizedBox(height: 18),
        Wrap(spacing: 7, runSpacing: 7, children: facts),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeader(title: 'жанры', compact: true),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final genre in genres) InfoChip(label: genre)],
          ),
        ],
        if (cast.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionHeader(
              title: widget._legacy ? 'в озвучке' : 'студии', compact: true),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final member in cast)
                InfoChip(
                  label: (widget._legacy && member is ReleaseMember) ? member.displayName : member.toString(),
                  icon: widget._legacy ? Icons.mic_none_rounded : Icons.business_rounded,
                ),
            ],
          ),
        ],
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              poster,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 7, runSpacing: 7, children: facts),
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final genre in genres.take(4))
                            InfoChip(label: genre, dense: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          descriptionBlock,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        poster,
        const SizedBox(width: 30),
        Expanded(child: descriptionBlock),
      ],
    );
  }
}
