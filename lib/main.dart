import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/app_services.dart';
import 'core/storage/library_store.dart';
import 'core/storage/playback_settings_store.dart';
import 'core/storage/search_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final services = AppServices(prefs: preferences);
  final library = LibraryStore(preferences);
  final search = SearchStore(preferences);
  final playback = PlaybackSettingsStore(preferences);

  runApp(
    AnishkaApp(
      services: services,
      library: library,
      search: search,
      playback: playback,
    ),
  );
}
