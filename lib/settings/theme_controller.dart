import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the theme setting and persists it on the device. Used through a single instance.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _storageKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Called once at startup. Follows the system setting when nothing is saved.
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
