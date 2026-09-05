import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 테마 설정을 들고 있으면서 기기에 저장한다.
/// 앱 전체에서 이 인스턴스 하나만 사용한다.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _storageKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// 앱 시작 시 한 번. 저장된 값이 없으면 시스템 설정을 따른다.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    _mode = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, mode.name);
  }
}

String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '시스템 설정 따르기',
  ThemeMode.light => '밝게',
  ThemeMode.dark => '어둡게',
};
