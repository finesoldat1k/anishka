import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:anishka/ui/icons/app_icons.dart';

import '../../core/models/anime_source.dart';
import '../../core/models/shikimori_anime.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/about/about_screen.dart';
import '../../features/details/details_screen.dart';
import '../../features/details/episodes_screen.dart';
import '../../features/details/related_screen.dart';
import '../../features/details/voiceover_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/search/search_screen.dart';
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
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const SearchScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.025),
                        end: Offset.zero,
                      ).animate(curved),
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.985,
                          end: 1,
                        ).animate(curved),
                        child: child,
                      ),
                    ),
                  );
                },
          );
        },
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const AboutScreen(),
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          );
        },
      ),
      GoRoute(
        path: '/anime/shikimori/:id',
        name: 'anime-shikimori',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) return const _RouteError();
          final extra = state.extra;
          final preview = extra is ShikimoriAnime ? extra : null;
          return DetailsScreen(shikimoriId: id, preview: preview);
        },
      ),
      GoRoute(
        path: '/anime/shikimori/:id/voices',
        name: 'anime-voices',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) return const _RouteError().asPage(state);
          final anime = state.extra is AnimeWithSources
              ? state.extra as AnimeWithSources
              : null;
          return _subpage(
            state,
            VoiceoverScreen(animeWithSources: anime, shikimoriId: id),
          );
        },
      ),
      GoRoute(
        path: '/anime/shikimori/:id/voices/:voiceId/episodes',
        name: 'anime-episodes',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          final voiceId = state.pathParameters['voiceId'] ?? '';
          if (id == null || id <= 0 || voiceId.isEmpty) {
            return const _RouteError().asPage(state);
          }
          final anime = state.extra is AnimeWithSources
              ? state.extra as AnimeWithSources
              : null;
          return _subpage(
            state,
            EpisodesScreen(
              voiceId: voiceId,
              animeWithSources: anime,
              shikimoriId: id,
            ),
          );
        },
      ),
      GoRoute(
        path: '/anime/shikimori/:id/related',
        name: 'anime-related',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) return const _RouteError().asPage(state);
          final extra = state.extra;
          final args = extra is RelatedArgs ? extra : null;
          final items = args?.items ?? (extra is List ? extra : null);
          return _subpage(
            state,
            RelatedScreen(items: items, shikimoriId: id, title: args?.title),
          );
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

/// Helper to build a consistent subpage transition.
CustomTransitionPage<void> _subpage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RouteError extends StatelessWidget {
  const _RouteError();

  CustomTransitionPage<void> asPage(GoRouterState state) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        child: this,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      );

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
                    AppIcons.compass,
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
                  icon: AppIcons.house,
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
