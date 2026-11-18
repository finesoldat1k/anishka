import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/models/anime_release.dart';
import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/storage/library_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/widgets/app_image.dart';
import '../../../ui/widgets/gradient_button.dart';
import '../../../ui/widgets/info_chip.dart';

class DetailsHero extends StatelessWidget {
  /// Legacy AniLibria-only constructor.
  const DetailsHero.legacy({
    super.key,
    required this.release,
    required this.compact,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onSelectStatus,
    required this.onRemoveStatus,
  })  : animeWithSources = null,
        _legacy = true;

  /// New Shikimori-based constructor with multiple sources.
  const DetailsHero.sources({
    super.key,
    required this.animeWithSources,
    required this.compact,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onSelectStatus,
    required this.onRemoveStatus,
  })  : release = null,
        _legacy = false;

  final AnimeRelease? release;
  final AnimeWithSources? animeWithSources;
  final bool compact;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final ValueChanged<CollectionStatus> onSelectStatus;
  final VoidCallback onRemoveStatus;
  final bool _legacy;

  /// The primary release for library operations.
  AnimeRelease? get _primaryRelease => _legacy ? release : animeWithSources?.defaultSource?.release;

  /// The primary Shikimori anime for display.
  ShikimoriAnimeDetails? get _shikimoriAnime => animeWithSources?.shikimoriAnime;

  /// Whether we have playable episodes.
  bool get _hasEpisodes => _legacy
      ? (release?.episodes.isNotEmpty ?? false)
      : (animeWithSources?.hasEpisodes ?? false);

  /// Whether playback is blocked.
  bool get _isBlocked => _legacy ? (release?.isBlocked ?? false) : false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final primaryRelease = _primaryRelease;
    final status = primaryRelease != null ? library.statusOf(primaryRelease.id) : null;
    final favorite = primaryRelease != null ? library.isFavorite(primaryRelease.id) : false;
    final progress = primaryRelease != null ? library.progressFor(primaryRelease.id) : null;
    final height = compact ? 460.0 : 490.0;
    final genres = _legacy
        ? (release?.displayGenres.take(compact ? 2 : 4).toList() ?? <String>[])
        : (_shikimoriAnime?.genres?.take(compact ? 2 : 4).map((g) => g.russian).toList() ?? <String>[]);

    final playButton = GradientButton(
      label: 'воспроизвести',
      icon: Icons.play_arrow_rounded,
      expand: compact,
      onTap: _hasEpisodes && !_isBlocked ? onPlay : null,
      height: 49,
    );

    final bookmark = _BookmarkButton(
      status: status,
      onSelected: onSelectStatus,
      onRemoved: onRemoveStatus,
    );

    final favoriteButton = GradientButton(
      label: favorite ? 'в избранном' : 'в избранное',
      icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      onTap: onToggleFavorite,
      ghost: true,
      expand: compact,
      height: 49,
    );

    final actions = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              playButton,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: bookmark),
                  const SizedBox(width: 10),
                  Expanded(child: favoriteButton),
                ],
              ),
            ],
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [playButton, bookmark, favoriteButton],
          );

    final note = _isBlocked
        ? 'релиз недоступен в вашем регионе по требованию правообладателя'
        : !_hasEpisodes
        ? 'серии ещё не вышли — загляните позже'
        : progress != null
        ? 'вы остановились на ${progress.episode} серии'
        : null;

    final backgroundUrl = _legacy ? release?.backgroundUrl : _shikimoriAnime?.backgroundUrl;
    final statusLabel = _legacy ? (release?.statusLabel ?? '') : (_shikimoriAnime?.statusLabel ?? '');
    final score = _legacy ? (release?.score) : (double.tryParse(_shikimoriAnime?.score ?? '') ?? 0.0);
    final year = _legacy ? release?.year : _shikimoriAnime?.year;
    final episodeCount = _legacy ? release?.episodeCount : _shikimoriAnime?.episodeCount;
    final ageRating = _legacy ? release?.ageRating : _shikimoriAnime?.rating;
    final displayTitle = _legacy ? (release?.displayTitle ?? '') : (_shikimoriAnime?.displayTitle ?? '');
    final displayEnglish = _legacy ? release?.displayEnglish : (_shikimoriAnime?.english?.isNotEmpty ?? false ? _shikimoriAnime!.english!.first : null);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(
            url: backgroundUrl,
            alignment: Alignment.topCenter,
            memCacheWidth: 1900,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x99060409),
                  Color(0xFF060409),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: compact ? 30 : 260,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.background.withValues(alpha: 0.92),
                    AppColors.background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: compact ? 330 : 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background.withValues(alpha: 0.88),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 44,
                    0,
                    compact ? 18 : 44,
                    compact ? 24 : 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          InfoChip(
                            label: statusLabel,
                            icon: Icons.circle,
                            accent: _legacy ? (release?.isOngoing ?? false) : (_shikimoriAnime?.isOngoing ?? false),
                            dense: true,
                          ),
                          if (score != null)
                            InfoChip(
                              label: formatScore(score),
                              icon: Icons.star_rounded,
                              dense: true,
                            ),
                          if (year != null)
                            InfoChip(label: '$year', dense: true),
                          if (episodeCount != null)
                            InfoChip(
                              label: episodesLabel(episodeCount),
                              dense: true,
                            ),
                          if (ageRating != null)
                            InfoChip(label: ageRating, dense: true),
                        ],
                      ),
                      SizedBox(height: compact ? 13 : 17),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 640 : 850,
                        ),
                        child: Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 28 : 46,
                            height: 1.03,
                            letterSpacing: compact ? -1 : -1.8,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 26,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (displayEnglish != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          displayEnglish,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: compact ? 11.5 : 13,
                            letterSpacing: 0.3,
                            color: AppColors.textSoft.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                      if (genres.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final genre in genres)
                              InfoChip(label: genre, dense: true),
                          ],
                        ),
                      ],
                      SizedBox(height: compact ? 15 : 22),
                      actions,
                      if (note != null) ...[
                        const SizedBox(height: 11),
                        Text(
                          note,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11.5,
                            color: _isBlocked
                                ? AppColors.danger
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({
    required this.status,
    required this.onSelected,
    required this.onRemoved,
  });

  final CollectionStatus? status;
  final ValueChanged<CollectionStatus> onSelected;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'закладка',
      offset: const Offset(0, 54),
      onSelected: (value) {
        if (value == 'remove') {
          onRemoved();
          return;
        }
        final selected = CollectionStatus.fromStorage(value);
        if (selected != null) onSelected(selected);
      },
      itemBuilder: (context) => [
        for (final item in CollectionStatus.values)
          PopupMenuItem<String>(
            value: item.name,
            child: Row(
              children: [
                Icon(
                  item == status
                      ? Icons.check_circle_rounded
                      : Icons.bookmark_border_rounded,
                  size: 17,
                  color: item == status
                      ? AppColors.accentBright
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(item.label),
              ],
            ),
          ),
        if (status != null)
          const PopupMenuItem<String>(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.close_rounded, size: 17, color: AppColors.danger),
                SizedBox(width: 10),
                Text('убрать закладку'),
              ],
            ),
          ),
      ],
      child: Container(
        height: 49,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: status != null
                ? AppColors.accent.withValues(alpha: 0.45)
                : AppColors.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == null
                  ? Icons.bookmark_border_rounded
                  : Icons.bookmark_rounded,
              size: 17,
              color: status == null
                  ? AppColors.textMuted
                  : AppColors.accentBright,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                status?.label ?? 'закладка',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
