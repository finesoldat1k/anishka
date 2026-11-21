import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:provider/provider.dart';

import '../../core/models/anime_source.dart';
import '../../core/models/voiceover.dart';
import '../../core/repository/anime_repository.dart';
import '../../core/storage/library_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/layout.dart';
import '../../ui/widgets/app_image.dart';
import '../../ui/widgets/skeleton.dart';
import '../../ui/widgets/source_note.dart';
import '../../ui/widgets/state_views.dart';
import 'widgets/subpage_header.dart';
import 'widgets/voice_avatar.dart';

/// First step of playback: pick a studio / voiceover track.
class VoiceoverScreen extends StatefulWidget {
  const VoiceoverScreen({super.key, this.animeWithSources, this.shikimoriId});

  /// Usually passed through GoRouter `extra`, so no request is needed.
  final AnimeWithSources? animeWithSources;
  final int? shikimoriId;

  @override
  State<VoiceoverScreen> createState() => _VoiceoverScreenState();
}

class _VoiceoverScreenState extends State<VoiceoverScreen> {
  late final AnimeRepository _repository;
  final _searchController = TextEditingController();
  AnimeWithSources? _anime;
  bool _loading = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = context.read<AnimeRepository>();
    _anime = widget.animeWithSources;
    if (_shouldLoad) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _shouldLoad =>
      _anime == null ||
      (_anime!.sources.isEmpty && _anime!.hasEpisodes == false);

  int? get _animeId => widget.shikimoriId ?? _anime?.shikimoriAnime.id;

  Future<void> _load({bool refresh = false}) async {
    final id = _animeId;
    if (id == null || id <= 0) {
      setState(() => _error = 'не удалось определить аниме.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final anime = await _repository.getAnimeWithSources(id, refresh: refresh);
      if (!mounted) return;
      setState(() => _anime = anime);
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

  void _openVoice(AnimeWithSources anime, VoiceoverInfo voice) {
    final id = anime.shikimoriAnime.id;
    context.push(
      '/anime/shikimori/$id/voices/${Uri.encodeComponent(voice.id)}/episodes',
      extra: anime,
    );
  }

  List<AnimeSource> _sourcesFor(AnimeWithSources anime) {
    final unique = <String, AnimeSource>{};
    for (final source in anime.sources) {
      if (source.episodes.isEmpty) continue;
      unique.putIfAbsent(source.voiceover.id, () => source);
    }
    return unique.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final padding = pagePadding(width);
    final anime = _anime;
    final library = context.watch<LibraryStore>();

    final sources = anime == null ? <AnimeSource>[] : _sourcesFor(anime);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? sources
        : sources
              .where(
                (source) =>
                    source.voiceover.title.toLowerCase().contains(query) ||
                    source.voiceover.subtitle.toLowerCase().contains(query),
              )
              .toList();

    final title = anime?.displayTitle ?? 'выбор озвучки';
    final poster = anime?.posterUrl;
    final totalEpisodes = sources.isEmpty
        ? 0
        : sources
              .map((source) => source.episodes.length)
              .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: SubpageHeader(
                      eyebrow: 'воспроизведение · шаг 1',
                      title: title,
                      subtitle: sources.isEmpty
                          ? 'озвучки этого тайтла'
                          : '${sources.length} ${_voicesLabel(sources.length)} · '
                                '${totalEpisodes > 0 ? '$totalEpisodes серий' : 'выберите студию'}',
                      onBack: _back,
                      compact: compact,
                      leading: poster == null || poster.isEmpty
                          ? null
                          : SizedBox(
                              width: compact ? 42 : 50,
                              child: AspectRatio(
                                aspectRatio: 2 / 3,
                                child: AppImage(
                                  url: poster,
                                  borderRadius: BorderRadius.circular(9),
                                  memCacheWidth: 150,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              if (sources.length > 6)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
                        child: _VoiceSearch(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                        ),
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
              else if (_loading && sources.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, 22, padding, 0),
                        child: Column(
                          children: [
                            for (var index = 0; index < 4; index++) ...[
                              const SkeletonBox(height: 86, borderRadius: 16),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (sources.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: AppIcons.waveform,
                    title: 'озвучки пока нет',
                    message:
                        'для этого тайтла не нашлось доступных студий. '
                        'попробуйте обновить страницу позже.',
                    actionLabel: 'обновить',
                    onAction: () => _load(refresh: true),
                    compact: true,
                  ),
                )
              else ...[
                if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: AppIcons.magnifyingGlassMinus,
                      title: 'ничего не найдено',
                      message: 'попробуйте другое название студии.',
                      compact: true,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padding, 22, padding, 0),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final source = filtered[index];
                        final progress = library.progressFor(source.release.id);
                        final isCurrent =
                            progress != null &&
                            progress.voice == source.voiceover.id;
                        return _VoiceTile(
                          source: source,
                          current: isCurrent,
                          lastEpisode: isCurrent ? progress.episode : null,
                          compact: compact,
                          onTap: () => _openVoice(anime!, source.voiceover),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: SourceNote(
                          padding: EdgeInsets.only(top: 30, bottom: 30),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _voicesLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'озвучка';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'озвучки';
    }
    return 'озвучек';
  }
}

class _VoiceSearch extends StatelessWidget {
  const _VoiceSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.magnifyingGlass,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 13,
                color: AppColors.text,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'найти студию озвучки',
                hintStyle: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'очистить',
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              icon: const Icon(AppIcons.x, size: 16),
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceTile extends StatefulWidget {
  const _VoiceTile({
    required this.source,
    required this.current,
    required this.lastEpisode,
    required this.compact,
    required this.onTap,
  });

  final AnimeSource source;
  final bool current;
  final int? lastEpisode;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends State<_VoiceTile>
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
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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

  @override
  Widget build(BuildContext context) {
    final voice = widget.source.voiceover;
    final episodeCount = widget.source.episodes.length;
    final tone = widget.current ? AppColors.planned : AppColors.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) {
        setState(() => _hovered = false);
        if (_pressed) {
          _pressController.reverse();
          setState(() => _pressed = false);
        }
      },
      child: ScaleTransition(
        scale: _pressAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 13 : 16,
                vertical: widget.compact ? 12 : 14,
              ),
              decoration: BoxDecoration(
                color: widget.current
                    ? tone.withValues(alpha: 0.07)
                    : _hovered
                    ? AppColors.surfaceHigh
                    : AppColors.surface.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.current
                      ? tone.withValues(alpha: 0.42)
                      : _hovered
                      ? AppColors.borderStrong
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  VoiceAvatar(
                    title: voice.title,
                    logoUrl: voice.logoUrl,
                    size: widget.compact ? 46 : 52,
                  ),
                  SizedBox(width: widget.compact ? 13 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                voice.title.toLowerCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.compact ? 13.5 : 15,
                                  letterSpacing: -0.3,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (widget.current) ...[
                              const SizedBox(width: 8),
                              _Tag(
                                label: widget.lastEpisode == null
                                    ? 'выбрано'
                                    : 'смотрели · ${widget.lastEpisode} серия',
                                color: AppColors.planned,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          voice.subtitle.toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _Tag(
                              label: widget.source.sourceType,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '$episodeCount ${_episodesLabel(episodeCount)}',
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 10.5,
                                color: AppColors.textFaint,
                              ),
                            ),
                            if (voice.participants.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              const Text(
                                '·',
                                style: TextStyle(
                                  color: AppColors.textFaint,
                                  fontSize: 10.5,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  voice.participants.take(3).join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 10.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSlide(
                    offset: _hovered ? const Offset(0.16, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      AppIcons.caretRight,
                      size: 20,
                      color: _hovered || widget.current
                          ? AppColors.textSoft
                          : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _episodesLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'серия';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'серии';
    }
    return 'серий';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label.toLowerCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w500,
          fontSize: 9,
          letterSpacing: 0.1,
          color: color,
        ),
      ),
    );
  }
}
