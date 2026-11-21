import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cache/cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/widgets/brand_mark.dart';
import '../../ui/widgets/gradient_button.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  CacheStats _stats = CacheStats.empty;
  bool _loadingStats = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final stats = await CacheService.stats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loadingStats = false;
    });
  }

  Future<void> _clearCache() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    await CacheService.clear();
    final stats = await CacheService.stats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _clearing = false;
      _loadingStats = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'кэш очищен',
          style: TextStyle(fontFamily: AppFonts.body, fontSize: 13),
        ),
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 32,
                16,
                compact ? 16 : 32,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoundButton(
                        icon: AppIcons.arrowLeft,
                        tooltip: 'назад',
                        onTap: () => _back(context),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'о приложении',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          letterSpacing: -0.4,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _BrandPanel(compact: compact, stats: _stats),
                  const SizedBox(height: 14),
                  _CachePanel(
                    compact: compact,
                    stats: _stats,
                    loading: _loadingStats,
                    clearing: _clearing,
                    onClear: _clearCache,
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'что это',
                    icon: AppIcons.sparkle,
                    compact: compact,
                    child: const Text(
                      'анишка — спокойный клиент для аниме без лишнего. '
                      'каталог и поиск работают через shikimori, серии '
                      'воспроизводятся с открытых источников, а библиотека '
                      'хранится только на вашем устройстве.',
                      style: _bodyStyle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'источники',
                    icon: AppIcons.broadcast,
                    compact: compact,
                    child: Column(
                      children: [
                        _SourceRow(
                          name: 'shikimori',
                          role: 'каталог, поиск, постеры и кадры из серий',
                          url: 'https://shikimori.io',
                        ),
                        _SourceRow(
                          name: 'anilibria',
                          role: 'озвучка студии и hls-серии',
                          url: 'https://anilibria.tv',
                        ),
                        _SourceRow(
                          name: 'animevost',
                          role: 'дополнительные серии в озвучке студии',
                          url: 'https://animevost.org',
                        ),
                        _SourceRow(
                          name: 'anidub',
                          role: 'дополнительные серии в озвучке студии',
                          url: 'https://anidub.com',
                        ),
                        _SourceRow(
                          name: 'anilist, kitsu и jikan',
                          role: 'трейлеры, рейтинги и запасные описания',
                          url: 'https://anilist.co',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'библиотека',
                    icon: AppIcons.lock,
                    compact: compact,
                    child: const Text(
                      'избранное, закладки и прогресс просмотра не покидают '
                      'устройство. аккаунт не нужен, регистрация не нужна, '
                      'аналитика не собирается.',
                      style: _bodyStyle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'дисклеймер',
                    icon: AppIcons.gavel,
                    compact: compact,
                    child: const Text(
                      'приложение не хранит и не распространяет видео. все '
                      'серии, постеры и описания принадлежат их авторам и '
                      'правообладателям. источники можно отключить, изменив '
                      'сборку приложения.',
                      style: _bodyStyle,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GradientButton(
                      label: 'вернуться к каталогу',
                      icon: AppIcons.arrowLeft,
                      ghost: true,
                      onTap: () => context.go('/'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'анишка · версия 1.0.0',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 10.5,
                        color: AppColors.textFaint,
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
  }
}

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontSize: 13,
  height: 1.6,
  color: AppColors.textSoft,
);

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.compact, required this.stats});

  final bool compact;
  final CacheStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 22 : 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.planned.withValues(alpha: 0.18),
            AppColors.surface.withValues(alpha: 0.86),
            AppColors.surfaceHigh.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.planned.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.planned.withValues(alpha: 0.10),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          const BrandMark(size: 52),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'анишка',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 16 : 20,
                    letterSpacing: -0.6,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'каталог, озвучки и плеер в одном спокойном месте.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatPill(icon: AppIcons.sparkle, label: 'версия 1.0.0'),
                    _StatPill(
                      icon: AppIcons.images,
                      label: '${stats.count} в кэше',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.planned),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 10.5,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _CachePanel extends StatelessWidget {
  const _CachePanel({
    required this.compact,
    required this.stats,
    required this.loading,
    required this.clearing,
    required this.onClear,
  });

  final bool compact;
  final CacheStats stats;
  final bool loading;
  final bool clearing;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'кэш',
      icon: AppIcons.images,
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading)
                      Container(
                        width: 110,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    else
                      Text(
                        stats.label,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 26 : 32,
                          letterSpacing: -1,
                          color: AppColors.text,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      'постеры, кадры из серий и трейлеры',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ClearButton(
                busy: clearing,
                enabled: !loading && stats.bytes > 0,
                onTap: onClear,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetaText(icon: AppIcons.images, label: '${stats.count} записей'),
              const SizedBox(width: 16),
              _MetaText(
                icon: AppIcons.clockCounterClockwise,
                label: '${stats.temporaryLabel} в памяти',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  const _ClearButton({
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.busy;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: active ? (_) => setState(() => _pressed = true) : null,
        onTapUp: active
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? (_hovered
                        ? AppColors.planned.withValues(alpha: 0.20)
                        : AppColors.planned.withValues(alpha: 0.12))
                  : AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? AppColors.planned.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.planned,
                    ),
                  )
                else
                  Icon(
                    AppIcons.x,
                    size: 15,
                    color: active ? AppColors.planned : AppColors.textFaint,
                  ),
                const SizedBox(width: 7),
                Text(
                  widget.busy ? 'очищаем' : 'очистить',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: active ? AppColors.planned : AppColors.textFaint,
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

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textFaint),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 11,
            color: AppColors.textFaint,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    required this.compact,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.planned.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.planned.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 16, color: AppColors.planned),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: -0.2,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.name, required this.role, required this.url});

  final String name;
  final String role;
  final String url;

  Future<void> _open() async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // External links are optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.planned,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 11),
            SizedBox(
              width: 118,
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.text,
                ),
              ),
            ),
            Expanded(
              child: Text(
                role,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Icon(
              AppIcons.arrowSquareOut,
              size: 13,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.8),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: AppColors.textSoft),
          ),
        ),
      ),
    );
  }
}
