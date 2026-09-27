import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';
  static const String _localeKey = 'app_locale';
  static const String _accentKey = 'accent_color';

  static final ValueNotifier<Color> primaryColor = ValueNotifier<Color>(
    Colors.deepPurple,
  );
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
    const Locale('en'),
  );

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.light;
    }

    locale.value = const Locale('en');
    await prefs.remove(_localeKey);

    final savedAccent = prefs.getInt(_accentKey);
    if (savedAccent != null) {
      primaryColor.value = Color(savedAccent);
    }
  }

  static Future<void> changePrimaryColor(Color color) async {
    primaryColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
  }

  static Future<void> toggleDarkMode(bool isDark) async {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, isDark ? 'dark' : 'light');
  }

  static Future<void> changeLocale(Locale newLocale) async {
    locale.value = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, newLocale.languageCode);
  }
}
