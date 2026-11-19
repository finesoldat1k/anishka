import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/repository/anime_repository.dart';
import 'core/router/app_router.dart';
import 'core/storage/library_store.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'ui/widgets/app_background.dart';

class AnishkaApp extends StatefulWidget {
  const AnishkaApp({super.key, required this.library});

  final LibraryStore library;

  @override
  State<AnishkaApp> createState() => _AnishkaAppState();
}

class _AnishkaAppState extends State<AnishkaApp> {
  late final AnimeRepository _repository = AnimeRepository();
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AnimeRepository>.value(value: _repository),
        ChangeNotifierProvider<LibraryStore>.value(value: widget.library),
      ],
      child: MaterialApp.router(
        title: 'anishka',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        scrollBehavior: const AppScrollBehavior(),
        routerConfig: _router,
        builder: (context, child) {
          return AppBackground(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}
