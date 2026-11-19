import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/widgets/brand_mark.dart';
import '../../ui/widgets/gradient_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
      backgroundColor: Colors.transparent,
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
                        icon: Icons.arrow_back_rounded,
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
                  _BrandPanel(compact: compact),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'что это',
                    icon: Icons.auto_awesome_rounded,
                    compact: compact,
                    child: const Text(
                      'anishka — спокойный клиент для аниме без лишнего. '
                      'каталог и поиск работают через shikimori, серии '
                      'воспроизводятся с открытых источников, а библиотека '
                      'хранится только на вашем устройстве.',
                      style: _bodyStyle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'источники',
                    icon: Icons.hub_outlined,
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
                          name: 'anilist и kitsu',
                          role: 'трейлеры, рейтинги и запасные описания',
                          url: 'https://anilist.co',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'библиотека',
                    icon: Icons.lock_outline_rounded,
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
                    icon: Icons.gavel_rounded,
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
                      icon: Icons.arrow_back_rounded,
                      ghost: true,
                      onTap: () => context.go('/'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'anishka · версия 1.0.0',
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
  const _BrandPanel({required this.compact});

  final bool compact;

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
            AppColors.accent.withValues(alpha: 0.16),
            AppColors.surface.withValues(alpha: 0.86),
            AppColors.surfaceHigh.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
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
                  'аниме без лишнего',
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
              ],
            ),
          ),
        ],
      ),
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
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(icon, size: 16, color: AppColors.accentBright),
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
  const _SourceRow({
    required this.name,
    required this.role,
    required this.url,
  });

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
                color: AppColors.accentBright,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 11),
            SizedBox(
              width: 108,
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
              Icons.open_in_new_rounded,
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
