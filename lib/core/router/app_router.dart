import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/anime_source.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/details/details_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/player/player_screen.dart';
import '../../ui/widgets/gradient_button.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/anime/:id',
        name: 'anime',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) return const _RouteError();
          return DetailsScreen(releaseId: id);
        },
      ),
      GoRoute(
        path: '/anime/shikimori/:id',
        name: 'anime-shikimori',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) return const _RouteError();
          return DetailsScreen(shikimoriId: id);
        },
      ),
      GoRoute(
        path: '/watch/:id/:episode',
        name: 'watch',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          final episode = int.tryParse(state.pathParameters['episode'] ?? '');
          final voice = state.uri.queryParameters['voice'];
          final source = state.extra is AnimeSource
              ? state.extra as AnimeSource
              : null;
          final child =
              (id == null || id <= 0 || episode == null || episode <= 0)
              ? const _RouteError()
              : PlayerScreen(
                  releaseId: id,
                  episodeOrdinal: episode,
                  voiceId: voice,
                  source: source,
                );
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: child,
            opaque: true,
            transitionDuration: const Duration(milliseconds: 240),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                    child: child,
                  );
                },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => const _RouteError(),
  );
}

class _RouteError extends StatelessWidget {
  const _RouteError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.explore_off_rounded,
                    color: AppColors.accentBright,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'страница не найдена',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: -0.4,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'возможно, ссылка устарела или в адресе опечатка.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'на главную',
                  icon: Icons.home_rounded,
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  height: 44,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
