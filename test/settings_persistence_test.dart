import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/shared/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to light theme and Arabic RTL locale', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());

    expect(settings.themeMode, ThemeMode.light);
    expect(settings.locale, const Locale('ar'));
    expect(settings.locale.languageCode, 'ar');
  });

  test('restores saved theme and language', () async {
    SharedPreferences.setMockInitialValues({
      AppSettings.themeKey: 'dark',
      AppSettings.languageKey: 'en',
    });
    final settings = AppSettings(await SharedPreferences.getInstance());

    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.locale, const Locale('en'));
    expect(settings.locale.languageCode, 'en');
  });

  test('persists theme and language changes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);

    await settings.saveTheme(ThemeMode.dark);
    await settings.saveLocale(const Locale('en'));

    final restored = AppSettings(await SharedPreferences.getInstance());
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.locale, const Locale('en'));
  });
}
