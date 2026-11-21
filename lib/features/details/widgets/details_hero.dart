import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/models/anime_release.dart';
import '../../../core/models/anime_source.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/storage/library_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../ui/icons/app_icons.dart';
import '../../../ui/widgets/app_image.dart';
import '../../../ui/widgets/gradient_button.dart';
import '../../../ui/widgets/trailer_view.dart';

/// Cinematic details hero.
///
/// The ambient trailer (muted, looping, no controls) fills the whole width.
/// Poster and title sit on top of it near the top of the page, so the first
/// screen already feels like a film rather than a catalogue card.
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
  }) : animeWithSources = null,
       librarySnapshot = null,
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
    this.librarySnapshot,
  }) : release = null,
       _legacy = false;

  final AnimeRelease? release;
  final AnimeWithSources? animeWithSources;

  /// Temporary library snapshot used before the first playable source loads,
  /// so favourite/status controls work immediately.
  final AnimeRelease? librarySnapshot;
  final bool compact;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final ValueChanged<CollectionStatus> onSelectStatus;
  final VoidCallback onRemoveStatus;
  final bool _legacy;

  AnimeRelease? get _primaryRelease => _legacy
      ? release
      : (animeWithSources?.defaultSource?.release ?? librarySnapshot);

  ShikimoriAnimeDetails? get _shikimoriAnime =>
      animeWithSources?.shikimoriAnime;

  bool get _hasEpisodes {
    if (_legacy) return release?.episodes.isNotEmpty ?? false;
    final anime = animeWithSources;
    if (anime == null) return false;
    if (anime.sources.isNotEmpty) return anime.hasEpisodes;
    // Sources are still loading. Keep play enabled for everything that is
    // not an announced title; the voices page will finish loading them.
    return anime.shikimoriAnime.status != 'anons';
  }

  bool get _isBlocked => _legacy ? (release?.isBlocked ?? false) : false;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryStore>();
    final primaryRelease = _primaryRelease;
    final status = primaryRelease != null
        ? library.statusOf(primaryRelease.id)
        : null;
    final favorite = primaryRelease != null
        ? library.isFavorite(primaryRelease.id)
        : false;
    final progress = primaryRelease != null
        ? library.progressFor(primaryRelease.id)
        : null;

    final shikimori = _shikimoriAnime;
    final displayTitle = _legacy
        ? (release?.displayTitle ?? '')
        : (shikimori?.displayTitle ?? '');
    final english = _legacy ? release?.displayEnglish : shikimori?.englishTitle;
    final statusLabel = _legacy
        ? (release?.statusLabel ?? '')
        : (shikimori?.statusLabel ?? '');
    final kindLabel = _legacy
        ? (release?.type ?? '')
        : (shikimori?.kindLabel ?? '');
    final score = _legacy ? release?.score : shikimori?.scoreValue;
    final year = _legacy ? release?.year : shikimori?.year;
    final episodeCount = _legacy
        ? release?.episodeCount
        : shikimori?.episodeCount;
    final ageRating = _legacy ? release?.ageRating : shikimori?.rating;
    final poster = _legacy
        ? release?.posterUrl
        : (shikimori?.posterOriginalUrl ?? shikimori?.posterUrl);
    final background = _legacy
        ? release?.backgroundUrl
        : (shikimori?.backgroundUrl ?? shikimori?.metadataBackground);
    final trailerId = _legacy ? null : shikimori?.trailerYoutubeId;

    final meta = <String>[
      if (year != null) '$year',
      if (kindLabel.isNotEmpty) kindLabel,
      if (episodeCount != null && episodeCount > 0) episodesLabel(episodeCount),
      if (score != null) formatScore(score),
      if (ageRating != null && ageRating.isNotEmpty) ageRating,
    ].join('  ·  ');

    final playButton = GradientButton(
      label: 'воспроизвести',
      icon: AppIcons.play,
      primary: true,
      expand: compact,
      onTap: _hasEpisodes && !_isBlocked ? onPlay : null,
      height: 49,
      tone: GradientButtonTone.play,
    );

    final bookmark = _BookmarkButton(
      status: status,
      onSelected: onSelectStatus,
      onRemoved: onRemoveStatus,
    );

    final favoriteButton = GradientButton(
      label: favorite ? 'в избранном' : 'в избранное',
      icon: AppIcons.heart,
      onTap: onToggleFavorite,
      tone: GradientButtonTone.favorite,
      active: favorite,
      expand: compact,
      height: 49,
    );

    final actions = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              playButton,
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: bookmark),
                  const SizedBox(width: 9),
                  Expanded(child: favoriteButton),
                ],
              ),
            ],
          )
        : Row(
            children: [
              playButton,
              const SizedBox(width: 10),
              bookmark,
              const SizedBox(width: 10),
              favoriteButton,
            ],
          );

    final note = _isBlocked
        ? 'релиз недоступен в вашем регионе по требованию правообладателя'
        : !_hasEpisodes
        ? 'серии ещё не вышли — загляните позже'
        : progress != null
        ? 'вы остановились на ${progress.episode} серии'
        : null;

    final height = compact ? 552.0 : 616.0;
    final posterWidth = compact ? 106.0 : 196.0;
    final gap = compact ? 16.0 : 28.0;

    // Use trailer as background if available, otherwise use poster/background
    final hasTrailer = trailerId != null;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background layer: trailer (ambient) or poster/background image
          if (hasTrailer)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster fallback keeps the hero alive on platforms where
                  // the embed is unavailable or still loading.
                  if (background != null && background.isNotEmpty)
                    AppImage(
                      url: background,
                      alignment: Alignment.topCenter,
                      memCacheWidth: 1900,
                    )
                  else if (poster != null && poster.isNotEmpty)
                    AppImage(
                      url: poster,
                      alignment: Alignment.topCenter,
                      memCacheWidth: 1200,
                    )
                  else
                    const ColoredBox(color: AppColors.backgroundLift),
                  IgnorePointer(
                    child: TrailerView(youtubeId: trailerId, ambient: true),
                  ),
                ],
              ),
            )
          else if (background != null && background.isNotEmpty)
            AppImage(
              url: background,
              alignment: Alignment.topCenter,
              memCacheWidth: 1900,
            )
          else
            const ColoredBox(color: AppColors.backgroundLift),

          // Scrim gradients for legibility
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x7A000000),
                  Color(0x33000000),
                  Color(0xE60B0A09),
                  AppColors.background,
                ],
                stops: [0, 0.34, 0.8, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xB30B0A09), Color(0x000B0A09)],
                stops: [0, 0.62],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 44,
                    compact ? 78 : 112,
                    compact ? 18 : 44,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Poster(
                        url: poster,
                        title: displayTitle,
                        width: posterWidth,
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: compact ? 2 : 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (statusLabel.isNotEmpty ||
                                  kindLabel.isNotEmpty)
                                _StatusLine(
                                  status: statusLabel,
                                  kind: kindLabel,
                                  ongoing: _legacy
                                      ? (release?.isOngoing ?? false)
                                      : (shikimori?.isOngoing ?? false),
                                ),
                              SizedBox(height: compact ? 8 : 12),
                              Text(
                                displayTitle,
                                maxLines: compact ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontWeight: FontWeight.w700,
                                  fontSize: compact ? 25 : 44,
                                  height: 1.05,
                                  letterSpacing: compact ? -1 : -1.8,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xB3000000),
                                      blurRadius: 28,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              if (english != null && english.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  english,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: compact ? 11 : 12.5,
                                    letterSpacing: 0.2,
                                    color: AppColors.textSoft.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                              ],
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  meta.toLowerCase(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontWeight: FontWeight.w500,
                                    fontSize: compact ? 11 : 12,
                                    letterSpacing: 0.2,
                                    color: AppColors.textSoft.withValues(
                                      alpha: 0.88,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: compact ? 15 : 24),
                              actions,
                              if (note != null) ...[
                                const SizedBox(height: 11),
                                Text(
                                  note,
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 11,
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

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.title, required this.width});

  final String? url;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 38,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AppImage(url: url, fallbackLabel: title, memCacheWidth: 520),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.status,
    required this.kind,
    required this.ongoing,
  });

  final String status;
  final String kind;
  final bool ongoing;

  @override
  Widget build(BuildContext context) {
    final tone = ongoing ? AppColors.watching : AppColors.completed;
    final parts = [status, kind]
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.toLowerCase())
        .join('  ·  ');
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tone,
            boxShadow: [
              BoxShadow(
                color: tone.withValues(alpha: 0.55),
                blurRadius: 9,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            parts,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1.5,
              color: AppColors.textSoft.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({
    required this.status,
    required this.onSelected,
    required this.onRemoved,
  });

  final CollectionStatus? status;
  final ValueChanged<CollectionStatus> onSelected;
  final VoidCallback onRemoved;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    _pressController.reverse();
    setState(() => _pressed = false);
  }

  Color get _tone => switch (widget.status) {
    CollectionStatus.planned => AppColors.planned,
    CollectionStatus.watching => AppColors.watching,
    CollectionStatus.completed => AppColors.completed,
    null => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final active = widget.status != null;
    final tone = _tone;

    return ScaleTransition(
      scale: _pressAnimation,
      child: PopupMenuButton<String>(
        tooltip: 'закладка',
        offset: const Offset(0, 54),
        onSelected: (value) {
          if (value == 'remove') {
            widget.onRemoved();
            return;
          }
          final selected = CollectionStatus.fromStorage(value);
          if (selected != null) widget.onSelected(selected);
        },
        itemBuilder: (context) => [
          for (final item in CollectionStatus.values)
            PopupMenuItem<String>(
              value: item.name,
              child: Row(
                children: [
                  Icon(
                    item == widget.status
                        ? AppIcons.checkCircle
                        : AppIcons.bookmarkSimple,
                    size: 17,
                    color: item == widget.status
                        ? _statusTone(item)
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(item.label),
                ],
              ),
            ),
          if (active)
            const PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(AppIcons.x, size: 17, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('убрать закладку'),
                ],
              ),
            ),
        ],
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) {
            setState(() => _hovered = false);
            if (_pressed) {
              _pressController.reverse();
              setState(() => _pressed = false);
            }
          },
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              height: 49,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: active
                    ? tone
                    : _hovered
                    ? tone.withValues(alpha: 0.15)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active || _hovered
                      ? tone.withValues(alpha: active ? 0.8 : 0.4)
                      : AppColors.borderStrong,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? AppIcons.bookmark : AppIcons.bookmarkSimple,
                    size: 17,
                    color: active || _hovered ? Colors.white : AppColors.text,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      widget.status?.label ?? 'закладка',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    AppIcons.caretDown,
                    size: 14,
                    color: active ? Colors.white : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusTone(CollectionStatus? status) => switch (status) {
    CollectionStatus.planned => AppColors.planned,
    CollectionStatus.watching => AppColors.watching,
    CollectionStatus.completed => AppColors.completed,
    null => AppColors.textMuted,
  };
}
