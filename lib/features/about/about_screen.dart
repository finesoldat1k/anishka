import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:anishka/ui/icons/app_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/service_info.dart';
import '../../core/cache/cache_service.dart';
import '../../core/config/image_proxy.dart';
import '../../core/services/app_services.dart';
import '../../core/storage/playback_settings_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/widgets/brand_mark.dart';
import '../../ui/widgets/gradient_button.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  CacheStats _stats = CacheStats.empty;
  bool _loadingStats = true;
  bool _clearing = false;
  ServicesHealth? _health;
  bool _checkingHealth = false;
  bool _proxyEnabled = ImageProxyConfig.enabled;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _refreshStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    final stats = await CacheService.stats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loadingStats = false;
    });
  }

  Future<void> _checkHealth() async {
    setState(() => _checkingHealth = true);
    final health = await context.read<AppServices>().healthCheck();
    if (!mounted) return;
    setState(() {
      _health = health;
      _checkingHealth = false;
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
    _showSnack('кэш очищен');
  }

  Future<void> _toggleProxy(bool value) async {
    setState(() => _proxyEnabled = value);
    ImageProxyConfig.enabled = value;
    _showSnack(
      value ? 'прокси изображений включён' : 'прокси изображений выключен',
    );
  }

  Future<void> _setPreferredProxy(String? proxyId) async {
    ImageProxyConfig.preferredProxy = proxyId == null
        ? null
        : ImageProxyConfig.proxies.firstWhere((p) => p.id == proxyId);
    _showSnack('прокси изменён');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: AppFonts.body, fontSize: 13),
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1100 : 980),
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
                        'настройки',
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

                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: compact,
                      tabAlignment: compact ? TabAlignment.start : null,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.text,
                      unselectedLabelColor: AppColors.textMuted,
                      labelStyle: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(AppIcons.speedometer, size: 16),
                          text: 'сервисы',
                        ),
                        Tab(
                          icon: Icon(AppIcons.video, size: 16),
                          text: 'видео',
                        ),
                        Tab(
                          icon: Icon(AppIcons.images, size: 16),
                          text: 'изображения',
                        ),
                        Tab(
                          icon: Icon(AppIcons.list, size: 16),
                          text: 'приоритеты',
                        ),
                        Tab(
                          icon: Icon(AppIcons.info, size: 16),
                          text: 'о приложении',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab Content
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ServicesTab(
                          compact: compact,
                          services: context.watch<AppServices>(),
                          health: _health,
                          checking: _checkingHealth,
                          onCheckHealth: _checkHealth,
                        ),
                        _VideoTab(
                          compact: compact,
                          settings: context.watch<PlaybackSettingsStore>(),
                        ),
                        _ImagesTab(
                          compact: compact,
                          proxyEnabled: _proxyEnabled,
                          onProxyToggle: _toggleProxy,
                          preferredProxy: ImageProxyConfig.preferredProxy?.id,
                          onProxyChange: _setPreferredProxy,
                          stats: _stats,
                          loading: _loadingStats,
                          clearing: _clearing,
                          onClearCache: _clearCache,
                        ),
                        _PriorityTab(
                          compact: compact,
                          services: context.watch<AppServices>(),
                        ),
                        _AboutTab(compact: compact),
                      ],
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

// ===== BRAND PANEL =====
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

// ===== ROUND BUTTON =====
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

// ===== PANEL =====
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    required this.compact,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool compact;
  final Widget? action;

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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: AppColors.text,
                  ),
                ),
              ),
              ...action != null ? [action!] : [],
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

// ===== SERVICES TAB =====
class _ServicesTab extends StatelessWidget {
  const _ServicesTab({
    required this.compact,
    required this.services,
    required this.health,
    required this.checking,
    required this.onCheckHealth,
  });

  final bool compact;
  final AppServices services;
  final ServicesHealth? health;
  final bool checking;
  final VoidCallback onCheckHealth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _ServiceGroup(
            title: 'метаданные',
            subtitle: 'каталог, поиск, описания, постеры, рейтинги',
            providers: services.allMetadata,
            enabled: services.isMetadataEnabled,
            toggle: (id, v) => services.toggleMetadata(id, v),
            healthById: _byId(health?.metadata),
            roles: const {
              'shikimori': 'основной каталог, поиск, постеры, кадры',
              'anilist': 'описания, студии, жанры, рейтинг, трейлеры',
              'jikan': 'запасные названия, описания, постеры, персонажи',
              'kitsu': 'английские названия, обложки, YouTube трейлеры',
              'yani': 'постеры, студии, озвучки, связи',
            },
          ),
          const SizedBox(height: 16),
          _ServiceGroup(
            title: 'источники видео',
            subtitle: 'озвучки, субтитры, HLS-потоки, серии',
            providers: services.allSources,
            enabled: services.isSourceEnabled,
            toggle: (id, v) => services.toggleSource(id, v),
            healthById: _byId(health?.sources),
            roles: const {
              'anilibria': 'основная студия, HLS серии, множественные озвучки',
              'yani': 'агрегатор студий, серии, треки',
              'kodik': 'озвучки kodik, прямые hls-потоки',
              'hdrezka': 'озвучки hdrezka, серии и фильмы',
              'animevost': 'озвучка animevost, mp4 серии',
              'sameband': 'озвучка sameband, hls серии',
              'anilibme': 'озвучка animelib, mp4 и kodik',
            },
          ),
          const SizedBox(height: 18),
          _HealthBar(
            checking: checking,
            ok:
                (health?.metadata.where((h) => h.ok).length ?? 0) +
                (health?.sources.where((h) => h.ok).length ?? 0),
            total:
                (health?.metadata.length ?? 0) + (health?.sources.length ?? 0),
            onCheck: onCheckHealth,
          ),
        ],
      ),
    );
  }

  Map<String, ServiceHealth> _byId(List<ServiceHealth>? list) {
    final map = <String, ServiceHealth>{};
    for (final h in list ?? const []) {
      map[h.id] = h;
    }
    return map;
  }
}

class _ServiceGroup extends StatelessWidget {
  const _ServiceGroup({
    required this.title,
    required this.subtitle,
    required this.providers,
    required this.enabled,
    required this.toggle,
    required this.healthById,
    required this.roles,
  });

  final String title;
  final String subtitle;
  final List<ServiceInfo> providers;
  final bool Function(String id) enabled;
  final void Function(String id, bool v) toggle;
  final Map<String, ServiceHealth> healthById;
  final Map<String, String> roles;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      icon: AppIcons.plugs,
      compact: true,
      action: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10.5,
          color: AppColors.textMuted,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: providers.map((p) {
          final id = p.id;
          final on = enabled(id);
          final health = healthById[id];
          return _ServiceTile(
            name: p.displayName,
            role: roles[id] ?? 'источник данных',
            id: id,
            value: on,
            onChanged: (v) => toggle(id, v),
            health: health,
            latency: health?.latency,
          );
        }).toList(),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.name,
    required this.role,
    required this.id,
    required this.value,
    required this.onChanged,
    required this.health,
    this.latency,
  });

  final String name;
  final String role;
  final String id;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ServiceHealth? health;
  final Duration? latency;

  @override
  Widget build(BuildContext context) {
    final ok = health?.ok;
    final dotColor = ok == null
        ? AppColors.textFaint
        : (ok ? AppColors.planned : AppColors.textFaint);
    final latencyText = latency != null
        ? '${latency!.inMilliseconds} мс'
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: value ? 0.4 : 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? AppColors.planned.withValues(alpha: 0.3)
                : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: value ? AppColors.text : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 10.5,
                  color: value ? AppColors.textSoft : AppColors.textMuted,
                ),
              ),
            ),
            if (latencyText != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ok == true
                      ? AppColors.planned.withValues(alpha: 0.15)
                      : AppColors.textFaint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  latencyText,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 9.5,
                    color: ok == true ? AppColors.planned : AppColors.textFaint,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.planned,
                activeTrackColor: AppColors.planned.withValues(alpha: 0.5),
                inactiveTrackColor: AppColors.surface.withValues(alpha: 0.5),
                inactiveThumbColor: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({
    required this.checking,
    required this.ok,
    required this.total,
    required this.onCheck,
  });

  final bool checking;
  final int ok;
  final int total;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final allOk = ok == total && total > 0;
    final statusColor = checking || total == 0
        ? AppColors.textMuted
        : (allOk ? AppColors.planned : AppColors.text);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onCheck,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: checking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.planned,
                      ),
                    )
                  : Icon(AppIcons.compass, size: 16, color: statusColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  checking
                      ? 'проверяем источники…'
                      : total == 0
                      ? 'нет данных о сервисах'
                      : 'работают $ok из $total сервисов',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12.5,
                    color: checking || allOk
                        ? AppColors.textSoft
                        : AppColors.text,
                    fontWeight: checking || allOk
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
                if (!checking && total > 0 && ok < total)
                  Text(
                    'недоступные сервисы пропускаются автоматически',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 10,
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

// ===== IMAGES TAB =====
class _ImagesTab extends StatelessWidget {
  const _ImagesTab({
    required this.compact,
    required this.proxyEnabled,
    required this.onProxyToggle,
    required this.preferredProxy,
    required this.onProxyChange,
    required this.stats,
    required this.loading,
    required this.clearing,
    required this.onClearCache,
  });

  final bool compact;
  final bool proxyEnabled;
  final ValueChanged<bool> onProxyToggle;
  final String? preferredProxy;
  final ValueChanged<String?> onProxyChange;
  final CacheStats stats;
  final bool loading;
  final bool clearing;
  final VoidCallback onClearCache;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Image Proxy Section
          _Panel(
            title: 'прокси изображений',
            icon: AppIcons.globe,
            compact: compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingRow(
                  title: 'включить прокси',
                  subtitle:
                      'обходит CORS для постеров shikimori и других источников',
                  trailing: Transform.scale(
                    scale: 0.85,
                    child: Switch.adaptive(
                      value: proxyEnabled,
                      onChanged: onProxyToggle,
                      activeThumbColor: AppColors.planned,
                      activeTrackColor: AppColors.planned.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingRow(
                  title: 'предпочитаемый прокси',
                  subtitle: 'авто — выбирает лучший для каждого хоста',
                  trailing: _ProxyDropdown(
                    value: preferredProxy,
                    onChanged: onProxyChange,
                    enabled: proxyEnabled,
                  ),
                ),
                const SizedBox(height: 8),
                if (proxyEnabled)
                  _ProxyList(
                    proxies: ImageProxyConfig.proxies,
                    current: preferredProxy,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'прокси выключен — постеры могут не загружаться из-за CORS',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Cache Section
          _Panel(
            title: 'кэш изображений',
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
                      onTap: onClearCache,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MetaText(
                      icon: AppIcons.images,
                      label: '${stats.count} записей',
                    ),
                    const SizedBox(width: 16),
                    _MetaText(
                      icon: AppIcons.clockCounterClockwise,
                      label: '${stats.temporaryLabel} в памяти',
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

class _VideoTab extends StatelessWidget {
  const _VideoTab({required this.compact, required this.settings});

  final bool compact;
  final PlaybackSettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _Panel(
            title: 'декодирование',
            icon: AppIcons.speedometer,
            compact: compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingRow(
                  title: 'пресет декодера',
                  subtitle: settings.decoder.description,
                  trailing: _SettingDropdown<VideoDecoderPreset>(
                    value: settings.decoder,
                    items: [
                      for (final preset in VideoDecoderPreset.values)
                        (value: preset, label: preset.label),
                    ],
                    onChanged: settings.setDecoder,
                  ),
                ),
                const SizedBox(height: 14),
                _SettingRow(
                  title: 'буфер',
                  subtitle: settings.buffer.description,
                  trailing: _SettingDropdown<VideoBufferPreset>(
                    value: settings.buffer,
                    items: [
                      for (final preset in VideoBufferPreset.values)
                        (value: preset, label: preset.label),
                    ],
                    onChanged: settings.setBuffer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'качество',
            icon: AppIcons.highDefinition,
            compact: compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingRow(
                  title: 'предпочитаемое качество',
                  subtitle: settings.quality.description,
                  trailing: _SettingDropdown<VideoQualityPreference>(
                    value: settings.quality,
                    items: [
                      for (final preset in VideoQualityPreference.values)
                        (value: preset, label: preset.label),
                    ],
                    onChanged: settings.setQuality,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'если видео подлагивает: включите «совместимость» или '
                    'программное декодирование, увеличьте буфер и выберите '
                    '720p. настройки можно менять прямо в плеере — кнопка '
                    'со спидометром в верхней панели. на web декодером '
                    'управляет браузер, поэтому там эти пресеты не влияют '
                    'на воспроизведение.',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: settings.reset,
                    icon: const Icon(
                      AppIcons.arrowCounterClockwise,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    label: const Text(
                      'сбросить настройки видео',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
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

class _SettingDropdown<T> extends StatelessWidget {
  const _SettingDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<({T value, String label})> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            color: AppColors.text,
          ),
          dropdownColor: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(value: item.value, child: Text(item.label)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _ProxyDropdown extends StatelessWidget {
  const _ProxyDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.surface
            : AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            color: enabled ? AppColors.text : AppColors.textMuted,
          ),
          dropdownColor: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('авто (рекомендуется)'),
            ),
            ...ImageProxyConfig.proxies.map(
              (p) => DropdownMenuItem<String>(value: p.id, child: Text(p.name)),
            ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _ProxyList extends StatelessWidget {
  const _ProxyList({required this.proxies, required this.current});

  final List<ImageProxyService> proxies;
  final String? current;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: proxies.map((p) {
        final isCurrent =
            current == p.id || (current == null && p == proxies.first);
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.planned.withValues(alpha: 0.08)
                : AppColors.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent
                  ? AppColors.planned.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.planned : AppColors.textFaint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: isCurrent ? AppColors.text : AppColors.textSoft,
                      ),
                    ),
                    Text(
                      p.notes,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Icon(AppIcons.check, size: 16, color: AppColors.planned),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ===== PRIORITY TAB =====
class _PriorityTab extends StatelessWidget {
  const _PriorityTab({required this.compact, required this.services});

  final bool compact;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final registry = services.registry;
    final metadataProviders = registry.enabledMetadata;
    final sourceProviders = registry.enabledSources;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _Panel(
            title: 'приоритет метаданных',
            icon: AppIcons.list,
            compact: compact,
            action: Text(
              'первый в списке — пробуется первым при загрузке',
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
            child: _PriorityList(
              providers: metadataProviders,
              isMetadata: true,
              onReorder: (oldIndex, newIndex) {
                registry.reorderMetadata(oldIndex, newIndex);
              },
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'приоритет источников видео',
            icon: AppIcons.filmStrip,
            compact: compact,
            action: Text(
              'используется для выбора озвучки при воспроизведении',
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
            child: _PriorityList(
              providers: sourceProviders,
              onReorder: (oldIndex, newIndex) {
                registry.reorderSources(oldIndex, newIndex);
              },
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'назначение провайдеров',
            icon: AppIcons.funnel,
            compact: compact,
            child: Column(
              children: [
                _PurposeRow(
                  purpose: 'каталог и поиск',
                  recommended: 'shikimori',
                  current: 'shikimori (единственный)',
                  description: 'использует API shikimori для списков и поиска',
                ),
                _PurposeRow(
                  purpose: 'описания и рейтинги',
                  recommended: 'shikimori',
                  current: 'shikimori',
                  description:
                      'Shikimori даёт описания, студии, жанры, рейтинг',
                ),
                _PurposeRow(
                  purpose: 'постеры и обложки',
                  recommended: 'shikimori',
                  current: 'shikimori',
                  description: 'Shikimori даёт постеры и фоновые изображения',
                ),
                _PurposeRow(
                  purpose: 'трейлеры',
                  recommended: 'shikimori',
                  current: 'shikimori (YouTube ID)',
                  description: 'Shikimori возвращает YouTube ID трейлеров',
                ),
                _PurposeRow(
                  purpose: 'озвучка и серии',
                  recommended: 'anilibria / yani / kodik / hdrezka / animevost / sameband / anilibme',
                  current: 'anilibria → yani → kodik → hdrezka → animevost → sameband → anilibme',
                  description: 'AniLibria — лучшее качество HLS, Yani — агрегатор, Kodik/HDRezka — крупные библиотеки озвучек, AnimeVost/SameBand/AnilibMe — прямые API',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityList extends StatefulWidget {
  const _PriorityList({
    required this.providers,
    required this.onReorder,
    this.isMetadata = false,
  });

  final List<ServiceInfo> providers;
  final void Function(int, int) onReorder;
  final bool isMetadata;

  @override
  State<_PriorityList> createState() => _PriorityListState();
}

class _PriorityListState extends State<_PriorityList> {
  late List<ServiceInfo> _providers;

  @override
  void initState() {
    super.initState();
    _providers = List.from(widget.providers);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _providers.removeAt(oldIndex);
          _providers.insert(newIndex, item);
        });
        widget.onReorder(oldIndex, newIndex);
      },
      children: _providers.asMap().entries.map((entry) {
        final index = entry.key;
        final p = entry.value;
        final id = p.id;
        final name = p.displayName;
        return Container(
          key: ValueKey(id),
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.planned.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.planned,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      'id: $id',
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 9.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  AppIcons.dotsThreeVertical,
                  size: 18,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PurposeRow extends StatelessWidget {
  const _PurposeRow({
    required this.purpose,
    required this.recommended,
    required this.current,
    required this.description,
  });

  final String purpose;
  final String recommended;
  final String current;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                purpose,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.planned.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'рекомендуется: $recommended',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 9,
                    color: AppColors.planned,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(AppIcons.arrowRight, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'текущий: $current',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 10.5,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== ABOUT TAB =====
class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
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
            title: 'источники данных',
            icon: AppIcons.broadcast,
            compact: compact,
            child: Column(
              children: [
                _SourceRow(
                  name: 'shikimori',
                  role: 'каталог, поиск, постеры, кадры из серий',
                  url: 'https://shikimori.io',
                ),
                _SourceRow(
                  name: 'anilibria',
                  role: 'озвучка студии и HLS-серии',
                  url: 'https://anilibria.tv',
                ),
                _SourceRow(
                  name: 'yani',
                  role: 'агрегатор студий озвучки, серии, треки',
                  url: 'https://yani.tv',
                ),
                _SourceRow(
                  name: 'animevost',
                  role: 'озвучка через api.animevost.org',
                  url: 'https://animevost.org',
                ),
                _SourceRow(
                  name: 'kodik',
                  role: 'озвучки Kodik, прямые HLS-потоки',
                  url: 'https://kodik.info',
                ),
                _SourceRow(
                  name: 'hdrezka',
                  role: 'озвучки HDRezka, серии и фильмы',
                  url: 'https://hdrezka-home.tv',
                ),
                _SourceRow(
                  name: 'sameband',
                  role: 'озвучка SameBand Studio',
                  url: 'https://sameband.studio',
                ),
                _SourceRow(
                  name: 'anilibme',
                  role: 'озвучка AnimeLib',
                  url: 'https://animelib.org',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'библиотека и приватность',
            icon: AppIcons.lock,
            compact: compact,
            child: const Text(
              'избранное, закладки и прогресс просмотра не покидают '
              'устройство. аккаунт не нужен, регистрация не нужна, '
              'аналитика не собирается. всё хранится локально.',
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
              'правообладателям. источники можно включить/выключить в настройках.',
              style: _bodyStyle,
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            title: 'разработка',
            icon: AppIcons.buildings,
            compact: compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourceRow(
                  name: 'flutter + material 3',
                  role: 'фреймворк и дизайн-система',
                  url: 'https://flutter.dev',
                ),
                _SourceRow(
                  name: 'media_kit',
                  role: 'видеоплеер с поддержкой HLS',
                  url: 'https://github.com/media-kit/media-kit',
                ),
                _SourceRow(
                  name: 'cached_network_image',
                  role: 'кэширование изображений',
                  url: 'https://pub.dev/packages/cached_network_image',
                ),
                _SourceRow(
                  name: 'go_router',
                  role: 'навигация',
                  url: 'https://pub.dev/packages/go_router',
                ),
              ],
            ),
          ),
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
