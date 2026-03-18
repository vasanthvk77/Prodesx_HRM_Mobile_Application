import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// THEME PROVIDER
/// Manages Light/Dark mode and persists the choice to secure storage.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  // We default to Dark Mode as per the project requirements
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  final _storage = const FlutterSecureStorage();
  final String _themeKey = 'theme_mode';

  /// Loads the saved theme on app startup.
  Future<void> _loadTheme() async {
    final savedTheme = await _storage.read(key: _themeKey);
    if (savedTheme == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  /// Toggles between light and dark modes.
  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      await _storage.write(key: _themeKey, value: 'dark');
    } else {
      state = ThemeMode.light;
      await _storage.write(key: _themeKey, value: 'light');
    }
  }

  bool get isDarkMode => state == ThemeMode.dark;
}
