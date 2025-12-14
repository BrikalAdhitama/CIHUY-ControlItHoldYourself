// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'pref_is_dark_mode';

  bool _isDarkMode;

  // Konstruktor utama, diisi dari nilai awal (misalnya hasil baca SharedPreferences)
  ThemeProvider(this._isDarkMode);

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Dipanggil dari switch di SettingsScreen
  Future<void> toggleTheme(bool value) async {
    // Kalau nilainya sama, ga usah ngapa-ngapain
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    notifyListeners();

    // Simpan preferensi ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isDarkMode);
  }

  /// Factory async buat inisialisasi pertama kali di main()
  static Future<ThemeProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    // default: false (light mode)
    final saved = prefs.getBool(_prefKey) ?? false;
    return ThemeProvider(saved);
  }
}
