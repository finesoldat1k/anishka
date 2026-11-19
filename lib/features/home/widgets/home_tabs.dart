import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../home_tab.dart';

/// Responsive tab bar: equal-width segments on desktop, scrollable pills on
/// mobile. The selected tab is kept in view automatically.
class HomeTabs extends StatefulWidget {
  const HomeTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.counts,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelected;
  final Map<HomeTab, int> counts;

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  late final List<GlobalKey> _keys = List.generate(
    HomeTab.values.length,
    (index) => GlobalKey(),
  );

  @override
  void didUpdateWidget(covariant HomeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = _keys[widget.selected.index].currentContext;
        if (context == null) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final tabs = [
          for (final tab in HomeTab.values)
            _TabButton(
              key: _keys[tab.index],
              tab: tab,
              selected: tab == widget.selected,
              count: widget.counts[tab] ?? 0,
              compact: compact,
              onTap: () => widget.onSelected(tab),
            ),
        ];

        final content = compact
            ? ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        tabs[i],
                      ],
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: tabs[i]),
                    ],
                  ],
                ),
              );

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: content,
        );
      },
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    super.key,
    required this.tab,
    required this.selected,
    required this.count,
    required this.compact,
    required this.onTap,
  });

  final HomeTab tab;
  final bool selected;
  final int count;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final countVisible = widget.count > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 40,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 13 : 10,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.24),
                        AppColors.accentDeep.withValues(alpha: 0.12),
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : _hovered
                  ? AppColors.surfaceHigh.withValues(alpha: 0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.tab.icon,
                  size: 16,
                  color: selected
                      ? AppColors.accentBright
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: widget.compact ? 12.5 : 12,
                      color: selected
                          ? AppColors.text
                          : AppColors.textSoft,
                    ),
                  ),
                ),
                if (countVisible) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.28)
                          : AppColors.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.35)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${widget.count}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.accentBright
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
