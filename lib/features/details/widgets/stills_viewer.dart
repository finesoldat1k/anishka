import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/app_image.dart';

/// Full-screen stills viewer with swipe navigation and thumbnail rail.
class StillsViewer extends StatefulWidget {
  const StillsViewer({
    super.key,
    required this.stills,
    required this.initialIndex,
  });

  final List<String> stills;
  final int initialIndex;

  @override
  State<StillsViewer> createState() => _StillsViewerState();
}

class _StillsViewerState extends State<StillsViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final _railController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stills.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _railController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.stills.length) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _scrollRailToIndex(index);
  }

  void _scrollRailToIndex(int index) {
    if (!_railController.hasClients) return;
    const itemWidth = 88.0;
    const spacing = 8.0;
    final targetOffset =
        index * (itemWidth + spacing) -
        (_railController.position.viewportDimension - itemWidth) / 2;
    _railController.animateTo(
      targetOffset.clamp(0.0, _railController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 760;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main image viewer with page swipe
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.stills.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final url = widget.stills[index];
              return Center(
                child: AppImage(url: url, fit: BoxFit.contain),
              );
            },
          ),

          // Top close button
          Positioned(
            right: isMobile ? 10 : 16,
            top: isMobile ? 10 : 16,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(AppIcons.x, size: 22, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // Previous arrow (kept below the close button)
          if (_currentIndex > 0)
            Positioned(
              left: 0,
              top: isMobile ? 68 : 80,
              bottom: isMobile ? 110 : 140,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _goTo(_currentIndex - 1),
                  child: Container(
                    width: isMobile ? 56 : 80,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 16,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      AppIcons.caretLeft,
                      size: isMobile ? 36 : 48,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),

          // Next arrow (kept below the close button)
          if (_currentIndex < widget.stills.length - 1)
            Positioned(
              right: 0,
              top: isMobile ? 68 : 80,
              bottom: isMobile ? 110 : 140,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _goTo(_currentIndex + 1),
                  child: Container(
                    width: isMobile ? 56 : 80,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 16,
                    ),
                    alignment: Alignment.centerRight,
                    child: Icon(
                      AppIcons.caretRight,
                      size: isMobile ? 36 : 48,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),

          // Thumbnail rail at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: isMobile ? 110 : 140,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 10 : 16,
                  isMobile ? 8 : 12,
                  isMobile ? 10 : 16,
                  isMobile ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.4, 1],
                  ),
                ),
                child: ListView.separated(
                  controller: _railController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.stills.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(width: isMobile ? 6 : 8),
                  itemBuilder: (context, index) {
                    final isCurrent = index == _currentIndex;
                    return GestureDetector(
                      onTap: () => _goTo(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: isMobile ? 76 : 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.planned
                                : Colors.white.withValues(alpha: 0.18),
                            width: isCurrent ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AppImage(
                                url: widget.stills[index],
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                              ),
                              if (isCurrent)
                                Container(
                                  color: AppColors.planned.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal stills gallery for the details page (draggable, no badges).
/// Supports hover expand, press animation, and drag scrolling.
class StillsGallery extends StatefulWidget {
  const StillsGallery({super.key, required this.stills, this.compact = false});

  final List<String> stills;
  final bool compact;

  @override
  State<StillsGallery> createState() => _StillsGalleryState();
}

class _StillsGalleryState extends State<StillsGallery> {
  int? _hoveredIndex;
  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.stills.isEmpty) return const SizedBox.shrink();

    final height = widget.compact ? 118.0 : 172.0;
    final width = height * 16 / 9;

    return SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          children: [
            // Right fade shadow for items that don't fit
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 44,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        AppColors.background,
                        AppColors.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.stills.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final url = widget.stills[index];
                final isHovered = _hoveredIndex == index;
                final isPressed = _pressedIndex == index;

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _pressedIndex = index),
                    onTapUp: (_) {
                      setState(() => _pressedIndex = null);
                      _openViewer(context, index);
                    },
                    onTapCancel: () => setState(() => _pressedIndex = null),
                    child: AnimatedScale(
                      scale: isPressed ? 0.96 : (isHovered ? 1.04 : 1.0),
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: width + (isHovered ? 16 : 0),
                        child: Material(
                          color: Colors.transparent,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppImage(
                                  url: url,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 900,
                                ),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                  border: Border.fromBorderSide(
                                    BorderSide(color: Color(0x1FFFFFFF)),
                                  ),
                                ),
                              ),
                              if (isHovered)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.3),
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: StillsViewer(stills: widget.stills, initialIndex: index),
        ),
      ),
    );
  }
}
