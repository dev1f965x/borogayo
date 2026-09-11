import 'package:flutter/material.dart';

import 'db/database.dart';
import 'media/media_store.dart';
import 'screens/project_list_screen.dart';
import 'settings/theme_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved theme first so the first frame already uses the right brightness.
  await ThemeController.instance.load();
  // Reclaim media files left behind, e.g. by room deletions that weren't undone.
  await MediaStore.cleanupOrphans(
    await AppDatabase.instance.readAllMediaPaths(),
  );
  runApp(const BorogayoApp());
}

class BorogayoApp extends StatelessWidget {
  const BorogayoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: '보러가요',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: ThemeController.instance.mode,
          home: const ProjectListScreen(),
        );
      },
    );
  }
}
