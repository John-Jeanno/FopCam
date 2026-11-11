import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService {
  static const _preferenceKey = 'app_theme_dark_mode';
  static final ValueNotifier<bool> isDarkMode = ValueNotifier(true);

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    isDarkMode.value = preferences.getBool(_preferenceKey) ?? true;
  }

  static Future<void> setDarkMode(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, enabled);
    isDarkMode.value = enabled;
  }
}
