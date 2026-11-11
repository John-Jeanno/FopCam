import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/constants/app_theme.dart';
import 'package:mobile/services/app_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppThemeService.isDarkMode.value = true;
  });

  test('defaults to night mode and restores the saved selection', () async {
    await AppThemeService.initialize();
    expect(AppThemeService.isDarkMode.value, isTrue);

    await AppThemeService.setDarkMode(false);
    expect(AppThemeService.isDarkMode.value, isFalse);

    AppThemeService.isDarkMode.value = true;
    await AppThemeService.initialize();
    expect(AppThemeService.isDarkMode.value, isFalse);
  });

  test('provides distinct day and night themes', () {
    expect(buildAppTheme().brightness, Brightness.dark);
    expect(buildAppTheme(isDark: false).brightness, Brightness.light);
  });
}
