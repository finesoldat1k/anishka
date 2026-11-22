import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/services/app_services.dart';
import 'core/repository/unified_repository.dart';
import 'core/router/app_router.dart';
import 'core/storage/library_store.dart';
import 'core/storage/search_store.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'ui/widgets/app_background.dart';

class AnishkaApp extends StatefulWidget {
  const AnishkaApp({
    super.key,
    required this.services,
    required this.library,
    required this.search,
  });

  final AppServices services;
  final LibraryStore library;
  final SearchStore search;

  @override
  State<AnishkaApp> createState() => _AnishkaAppState();
}

class _AnishkaAppState extends State<AnishkaApp> {
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
        ChangeNotifierProvider<AppServices>.value(value: widget.services),
        Provider<UnifiedRepository>.value(value: widget.services.repository),
        ChangeNotifierProvider<LibraryStore>.value(value: widget.library),
        ChangeNotifierProvider<SearchStore>.value(value: widget.search),
      ],
      child: MaterialApp.router(
        title: 'анишка',
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
