import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system; // Default ikut pengaturan HP

  bool get isDarkMode => themeMode == ThemeMode.dark;

  void toggleTheme(bool isOn) {
    themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // Kabari semua widget kalau tema berubah
  }
}

// --- PALET WARNA ---
class MyThemes {
  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFFE0F7FA), // Background Cyan Muda
    primaryColor: const Color(0xFF00796B),
    colorScheme: const ColorScheme.light(),
    cardColor: Colors.white, // Warna kartu di light mode
    iconTheme: const IconThemeData(color: Colors.black87),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.black87),
    ),
  );

  static final darkTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFF121212), // Background Hitam Gelap
    primaryColor: const Color(0xFF4DB6AC), // Teal yang lebih terang biar kebaca
    colorScheme: const ColorScheme.dark(),
    cardColor: const Color(0xFF1E1E1E), // Warna kartu di dark mode (abu gelap)
    iconTheme: const IconThemeData(color: Colors.white70),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}