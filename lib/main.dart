import 'package:flutter/material.dart';

import 'db/database.dart';
import 'media/media_store.dart';
import 'screens/project_list_screen.dart';
import 'screens/widgets/delete_action.dart';
import 'screens/widgets/toast.dart';
import 'settings/theme_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved theme first so the first frame already uses the right brightness.
  await ThemeController.instance.load();
  // Reclaim files whose rooms, buildings, or projects were deleted.
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
          navigatorObservers: [Toasts.instance.observer],
          builder: (context, child) => ToastHost(
            child: DeleteAction.collapseOnOutsideTouch(child: child!),
          ),
          home: const ProjectListScreen(),
        );
      },
    );
  }
}
