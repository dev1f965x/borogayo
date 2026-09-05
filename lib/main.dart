import 'package:flutter/material.dart';

import 'db/database.dart';
import 'media/media_store.dart';
import 'screens/project_list_screen.dart';
import 'settings/theme_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 저장된 테마를 먼저 읽어야 첫 프레임부터 올바른 밝기로 그려진다.
  await ThemeController.instance.load();
  // 되돌리지 않은 방 삭제 등으로 남은 미디어 파일을 회수한다.
  await MediaStore.cleanupOrphans(await AppDatabase.instance.readAllMediaPaths());
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
