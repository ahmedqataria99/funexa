import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings(this._preferences);

  static const themeKey = 'furnexa.theme';
  static const languageKey = 'furnexa.language';
  final SharedPreferences _preferences;

  ThemeMode get themeMode => _preferences.getString(themeKey) == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  Locale get locale => _preferences.getString(languageKey) == 'en'
      ? const Locale('en')
      : const Locale('ar');

  Future<bool> saveTheme(ThemeMode themeMode) => _preferences.setString(
    themeKey,
    themeMode == ThemeMode.dark ? 'dark' : 'light',
  );

  Future<bool> saveLocale(Locale locale) =>
      _preferences.setString(languageKey, locale.languageCode);
}
