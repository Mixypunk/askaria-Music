import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static ThemeNotifier? _instance;
  static ThemeNotifier get instance => _instance ??= ThemeNotifier._();
  ThemeNotifier._();

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system &&
       WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved  = prefs.getString('theme_mode') ?? 'dark';
    _mode = saved == 'light' ? ThemeMode.light
          : saved == 'system' ? ThemeMode.system
          : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? 'light'
        : mode == ThemeMode.system ? 'system' : 'dark');
    notifyListeners();
  }
}
