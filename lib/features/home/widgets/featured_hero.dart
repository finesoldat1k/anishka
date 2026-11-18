import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/anime_card_item.dart';
import '../../../core/models/anime_release.dart';
import '../../../core/models/shikimori_anime.dart';
import '../../../core/repository/anime_repository.dart';
import '../../../core/storage/library_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/youtube.dart';
import '../../../ui/widgets/app_image.dart';
import '../../../ui/widgets/gradient_button.dart';
import '../../../ui/widgets/info_chip.dart';
import '../../../ui/widgets/trailer_view.dart';

class FeaturedHero extends StatefulWidget {
  const FeaturedHero({super.key, required this.items, required this.onOpen});

  final List<dynamic> items;
  final void Function(dynamic anime) onOpen;

  @override
  State<FeaturedHero> createState() => _FeaturedHeroState();
}

class _FeaturedHeroState extends State<FeaturedHero> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant FeaturedHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _page = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || _hovered || !_controller.hasClients) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _toggleFavorite(dynamic anime) {
    final library = context.read<LibraryStore>();
    if (anime is AnimeRelease) {
      library.toggleFavorite(anime);
      return;
    }
    // shikimori-карточки не хранят релиз anilibria: избранное добавляется
    // со страницы тайтла, где уже загружены источники.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('откройте тайтл, чтобы добавить его в избранное'),
        ),
      );
  }

  void _goTo(int page) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 760;
        final height = compact ? (width < 420 ? 350.0 : 365.0) : 430.0;
        return MouseRegion(
          onEnter: (_) {
            _hovered = true;
            _timer?.cancel();
          },
          onExit: (_) {
            _hovered = false;
            _restartTimer();
          },
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.items.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) {
                      final anime = widget.items[index];
                      return _HeroSlide(
                        anime: anime,
                        compact: compact,
                        active: index == _page,
                        onOpen: () => widget.onOpen(anime),
                        onFavorite: () => _toggleFavorite(anime),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 18,
                  child: _PageCounter(page: _page, total: widget.items.length),
                ),
                if (!compact && widget.items.length > 1) ...[
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: _page == 0 ? null : () => _goTo(_page - 1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _ArrowButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: _page >= widget.items.length - 1
                            ? null
                            : () => _goTo(_page + 1),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  left: 27,
                  right: 27,
                  bottom: 15,
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 22 : 7,
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.accentBright
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: i == _page
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroSlide extends StatefulWidget {
  const _HeroSlide({
    required this.anime,
    required this.compact,
    required this.active,
    required this.onOpen,
    required this.onFavorite,
  });

  final dynamic anime;
  final bool compact;
  final bool active;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  @override
  State<_HeroSlide> createState() => _HeroSlideState();
}

class _HeroSlideState extends State<_HeroSlide> {
  String? _trailerId;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveTrailer());
  }

  @override
  void didUpdateWidget(covariant _HeroSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.anime, widget.anime)) {
      _trailerId = null;
      unawaited(_resolveTrailer());
    }
  }

  Future<void> _resolveTrailer() async {
    final anime = widget.anime;
    ShikimoriAnimeDetails? details;
    if (anime is ShikimoriAnimeDetails) {
      details = anime;
    } else if (anime is ShikimoriAnime) {
      try {
        details = await context.read<AnimeRepository>().getShikimoriDetails(
          anime.id,
        );
      } catch (_) {
        return;
      }
    }
    if (!mounted || details == null) return;

    final videos = details.videos;
    if (videos == null || videos.isEmpty) return;

    ShikimoriVideo? trailer;
    ShikimoriVideo? fallback;
    for (final video in videos) {
      if (video.hosting != 'youtube') continue;
      fallback ??= video;
      if (video.kind == 'pv' || video.kind == 'trailer') {
        trailer = video;
        break;
      }
    }
    final id = youtubeVideoId((trailer ?? fallback)?.url ?? '');
    if (id != null && mounted) setState(() => _trailerId = id);
  }

  Future<void> _openTrailer() async {
    final id = _trailerId;
    if (id == null) return;
    await launchUrl(
      Uri.parse('https://www.youtube.com/watch?v=$id'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final compact = widget.compact;
    final library = context.watch<LibraryStore>();
    final adapter = AnimeCardAdapter(anime);
    final favorite = library.isFavorite(adapter.libraryId ?? adapter.id);

    final genres = anime is AnimeRelease
        ? anime.displayGenres.take(3).toList()
        : anime is ShikimoriAnimeDetails
        ? (anime.genres ?? const [])
              .map((genre) => genre.russian)
              .where((genre) => genre.isNotEmpty)
              .take(3)
              .toList()
        : <String>[];

    final english = anime is AnimeRelease
        ? anime.displayEnglish
        : anime is ShikimoriAnimeDetails &&
              (anime.english?.isNotEmpty ?? false)
        ? anime.english!.first
        : null;

    final backgroundUrl =
        (anime is ShikimoriAnimeDetails ? anime.backgroundUrl : null) ??
        adapter.backgroundUrl;
    final showTrailer =
        kIsWeb && widget.active && _trailerId != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage(
          url: backgroundUrl,
          alignment: Alignment.topCenter,
          memCacheWidth: 1600,
        ),
        if (showTrailer)
          Positioned.fill(child: TrailerView(youtubeId: _trailerId!)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x33000000), Color(0x99060409), Color(0xF5060409)],
              stops: [0, 0.52, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.15),
                AppColors.background.withValues(alpha: 0.94),
              ],
              stops: const [0.25, 0.6, 1],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: compact ? 40 : 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.background.withValues(alpha: 0.88),
                  AppColors.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: compact ? 20 : 34,
          right: compact ? 20 : 160,
          bottom: compact ? 30 : 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (adapter.isOngoing)
                    const InfoChip(
                      label: 'в эфире',
                      icon: Icons.bolt_rounded,
                      accent: true,
                      dense: true,
                    ),
                  if (adapter.score != null)
                    InfoChip(
                      label: formatScore(adapter.score),
                      icon: Icons.star_rounded,
                      dense: true,
                    ),
                  if (adapter.year != null)
                    InfoChip(label: '${adapter.year}', dense: true),
                  if (adapter.episodeCount != null)
                    InfoChip(
                      label: episodesLabel(adapter.episodeCount),
                      dense: true,
                    ),
                ],
              ),
              SizedBox(height: compact ? 12 : 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 560 : 690),
                child: Text(
                  adapter.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 27 : 42,
                    height: 1.04,
                    letterSpacing: compact ? -0.9 : -1.5,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 24,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              if (english != null) ...[
                const SizedBox(height: 7),
                Text(
                  english,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: compact ? 11.5 : 13,
                    letterSpacing: 0.3,
                    color: AppColors.textSoft.withValues(alpha: 0.85),
                  ),
                ),
              ],
              if (!compact && genres.isNotEmpty) ...[
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GradientButton(
                    label: 'подробнее',
                    icon: Icons.arrow_forward_rounded,
                    onTap: widget.onOpen,
                    height: compact ? 43 : 48,
                  ),
                  GradientButton(
                    label: favorite ? 'в избранном' : 'в избранное',
                    icon: favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    onTap: widget.onFavorite,
                    ghost: true,
                    height: compact ? 43 : 48,
                  ),
                  if (_trailerId != null)
                    GradientButton(
                      label: 'трейлер',
                      icon: Icons.movie_filter_rounded,
                      onTap: _openTrailer,
                      ghost: true,
                      height: compact ? 43 : 48,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageCounter extends StatelessWidget {
  const _PageCounter({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        '${page + 1} / $total',
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSoft,
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.25,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: AppColors.background.withValues(alpha: 0.5),
        shape: const CircleBorder(side: BorderSide(color: Color(0x26FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 22, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
