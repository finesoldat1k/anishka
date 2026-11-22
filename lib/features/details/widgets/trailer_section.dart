import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart' show AppFonts;
import '../../../ui/icons/app_icons.dart';
import '../../../ui/widgets/app_image.dart';

/// Trailer section below related releases.
class TrailerSection extends StatefulWidget {
  const TrailerSection({
    super.key,
    required this.trailerYoutubeId,
    required this.trailerThumbnail,
    required this.trailerTitle,
    this.compact = false,
  });

  final String? trailerYoutubeId;
  final String? trailerThumbnail;
  final String? trailerTitle;
  final bool compact;

  @override
  State<TrailerSection> createState() => _TrailerSectionState();
}

class _TrailerSectionState extends State<TrailerSection> {
  Player? _player;
  VideoController? _controller;
  bool _playing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

Future<void> _ensurePlayer() async {
    if (_player != null) return;
    _player = Player(
      configuration: PlayerConfiguration(
        logLevel: const bool.fromEnvironment('dart.library.html')
            ? MPVLogLevel.error
            : MPVLogLevel.error,
      ),
    );
    _controller = VideoController(_player!);
    await _player!.setVolume(0.8);
  }

  Future<void> _playTrailer() async {
    await _ensurePlayer();
    final url = 'https://www.youtube.com/watch?v=${widget.trailerYoutubeId}';
    await _player!.open(Media(url), play: true);
    setState(() => _playing = true);
  }

  Future<void> _pauseTrailer() async {
    await _player?.pause();
    setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trailerYoutubeId == null || widget.trailerYoutubeId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = widget.compact ? 280.0 : 360.0;
    final height = width * 9 / 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 18 : 24),
          child: Text(
            'трейлеры',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w500,
              fontSize: widget.compact ? 14 : 16,
              letterSpacing: -0.4,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 18 : 24),
          child: SizedBox(
            width: width,
            child: _TrailerCard(
              youtubeId: widget.trailerYoutubeId!,
              thumbnail: widget.trailerThumbnail,
              title: widget.trailerTitle ?? 'Трейлер',
              width: width,
              height: height,
              compact: widget.compact,
              playing: _playing,
              onPlay: _playTrailer,
              onPause: _pauseTrailer,
              controller: _controller,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({
    required this.youtubeId,
    required this.thumbnail,
    required this.title,
    required this.width,
    required this.height,
    required this.compact,
    required this.playing,
    required this.onPlay,
    required this.onPause,
    this.controller,
  });

  final String youtubeId;
  final String? thumbnail;
  final String title;
  final double width;
  final double height;
  final bool compact;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VideoController? controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: playing ? onPause : onPlay,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video player or thumbnail
                if (playing && controller != null)
                  Video(controller: controller!)
                else if (thumbnail != null && thumbnail!.isNotEmpty)
                  AppImage(
                    url: thumbnail!,
                    fit: BoxFit.cover,
                    memCacheWidth: (width * 2).round(),
                  )
                else
                  AppImage(
                    url: 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                    fit: BoxFit.cover,
                    memCacheWidth: (width * 2).round(),
                  ),
                // Dark overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: playing ? 0.2 : 0.85),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
                // Play/Pause button
                Center(
                  child: Container(
                    width: compact ? 56 : 72,
                    height: compact ? 56 : 72,
                    decoration: BoxDecoration(
                      color: AppColors.planned.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.planned.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      playing ? AppIcons.pause : AppIcons.play,
                      size: compact ? 24 : 30,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Title at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 10 : 14),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 11.5 : 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
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