import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    final box = await Hive.openBox('settings');
    final mode = box.get('themeMode');
    if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final box = await Hive.openBox('settings');
    if (mode == ThemeMode.light) {
      await box.put('themeMode', 'light');
    } else if (mode == ThemeMode.dark) {
      await box.put('themeMode', 'dark');
    } else {
      await box.put('themeMode', 'system');
    }
    notifyListeners();
  }
} 