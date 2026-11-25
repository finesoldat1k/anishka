import 'package:material_ui/material_ui.dart';

import '../../core/models/anime_episode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/icons/app_icons.dart';
import '../../ui/widgets/episode_card.dart';

/// In-player episode picker.
///
/// The voiceover is already chosen when the player opens, so the sheet only
/// lists episodes of the current source. Tapping a card closes the sheet and
/// returns the episode; the caller starts playback immediately.
Future<AnimeEpisode?> showEpisodePickerSheet(
  BuildContext context, {
  required List<AnimeEpisode> episodes,
  required String voiceTitle,
  int? currentOrdinal,
}) {
  if (episodes.isEmpty) return Future<AnimeEpisode?>.value();
  final sorted = [...episodes]..sort((a, b) => a.ordinal.compareTo(b.ordinal));
  return showModalBottomSheet<AnimeEpisode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.74),
    useSafeArea: true,
    builder: (context) => _EpisodePickerSheet(
      episodes: sorted,
      voiceTitle: voiceTitle,
      currentOrdinal: currentOrdinal,
    ),
  );
}

class _EpisodePickerSheet extends StatefulWidget {
  const _EpisodePickerSheet({
    required this.episodes,
    required this.voiceTitle,
    this.currentOrdinal,
  });

  final List<AnimeEpisode> episodes;
  final String voiceTitle;
  final int? currentOrdinal;

  @override
  State<_EpisodePickerSheet> createState() => _EpisodePickerSheetState();
}

class _EpisodePickerSheetState extends State<_EpisodePickerSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _positioned = false;

  static const _separator = 8.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_positioned) return;
    _positioned = true;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final itemExtent = (compact ? 68.0 : 78.0) + _separator;
    final index = widget.episodes.indexWhere(
      (episode) => episode.ordinal == widget.currentOrdinal,
    );
    if (index <= 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo((index - 2) * itemExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 720;
    final radius = compact
        ? const BorderRadius.vertical(top: Radius.circular(28))
        : BorderRadius.circular(28);
    final listMaxHeight = media.height * 0.58;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: media.height * 0.88,
        ),
        child: Container(
          margin: EdgeInsets.fromLTRB(
            compact ? 0 : 18,
            0,
            compact ? 0 : 18,
            compact ? 0 : 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundLift,
            borderRadius: radius,
            border: Border.all(
              color: compact ? Colors.transparent : AppColors.borderStrong,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.10),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 26,
                    16,
                    compact ? 18 : 26,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'серии',
                              style: TextStyle(
                                fontFamily: AppFonts.display,
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                letterSpacing: -0.5,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'озвучка: ${widget.voiceTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(AppIcons.x, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: listMaxHeight),
                    child: ListView.separated(
                      controller: _scrollController,
                      shrinkWrap: widget.episodes.length <= 60,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        compact ? 18 : 26,
                        4,
                        compact ? 18 : 26,
                        compact
                            ? 22 + MediaQuery.paddingOf(context).bottom
                            : 26,
                      ),
                      itemCount: widget.episodes.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: _separator),
                      itemBuilder: (context, index) {
                        final episode = widget.episodes[index];
                        return EpisodeCard(
                          episode: episode,
                          current: episode.ordinal == widget.currentOrdinal,
                          currentLabel: 'сейчас',
                          compact: compact,
                          onTap: episode.hasStream
                              ? () => Navigator.of(context).pop(episode)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
