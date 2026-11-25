import 'package:material_ui/material_ui.dart';

import '../../core/models/anime_episode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../icons/app_icons.dart';

/// Episode row shared by the episodes page and the in-player picker.
///
/// The current episode gets a subtle purple tint instead of a full accent
/// fill, so the list stays readable while the active item is still obvious.
class EpisodeCard extends StatefulWidget {
  const EpisodeCard({
    super.key,
    required this.episode,
    required this.current,
    required this.compact,
    required this.onTap,
    this.currentLabel = 'сейчас',
  });

  final AnimeEpisode episode;
  final bool current;
  final bool compact;
  final VoidCallback? onTap;
  final String currentLabel;

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard>
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
    if (widget.onTap != null) {
      _pressController.forward();
      setState(() => _pressed = true);
    }
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
    final episode = widget.episode;
    final enabled = widget.onTap != null;
    final currentTone = AppColors.planned;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: widget.compact ? 68 : 78,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.current
                    ? currentTone.withValues(alpha: 0.10)
                    : _hovered
                    ? AppColors.surfaceHigh
                    : AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.current
                      ? currentTone.withValues(alpha: 0.38)
                      : _hovered
                      ? AppColors.planned.withValues(alpha: 0.32)
                      : AppColors.border,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 12 : 16,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: widget.compact ? 32 : 42,
                      child: Text(
                        episode.ordinal.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w600,
                          fontSize: widget.compact ? 14 : 16,
                          letterSpacing: -0.4,
                          color: widget.current
                              ? currentTone
                              : _hovered
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            episode.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontWeight: FontWeight.w500,
                              fontSize: widget.compact ? 12.5 : 14,
                              letterSpacing: -0.2,
                              color: !enabled
                                  ? AppColors.textFaint
                                  : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'серия ${episode.ordinal}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 10.5,
                                  color: AppColors.textFaint,
                                ),
                              ),
                              if (episode.duration != null) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '·',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formatDuration(episode.duration!),
                                  style: const TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 10.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ],
                              if (widget.current) ...[
                                const SizedBox(width: 8),
                                Text(
                                  widget.currentLabel,
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    color: currentTone,
                                  ),
                                ),
                              ],
                              if (!enabled) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  'недоступно',
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 10,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedOpacity(
                      opacity: enabled && _hovered ? 1 : 0.72,
                      duration: const Duration(milliseconds: 170),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        width: widget.compact ? 32 : 36,
                        height: widget.compact ? 32 : 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled && _hovered
                              ? AppColors.planned.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: enabled && _hovered
                                ? AppColors.planned.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Icon(
                          AppIcons.play,
                          size: widget.compact ? 17 : 19,
                          color: enabled
                              ? (_hovered
                                    ? AppColors.planned
                                    : AppColors.textSoft)
                              : AppColors.textFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
