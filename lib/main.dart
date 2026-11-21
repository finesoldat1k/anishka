import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/library_store.dart';
import 'core/storage/search_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final library = LibraryStore(preferences);
  final search = SearchStore(preferences);

  runApp(AnishkaApp(library: library, search: search));
}
