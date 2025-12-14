// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// ----- FIREBASE IMPORTS -----
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- INI WAJIB DITAMBAH

import 'services/fcm_service.dart';
import 'models/chat_message.dart';
import 'models/chat_thread.dart';
import 'models/hive_adapters.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/pdf_viewer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INISIALISASI YANG MEMANG SUDAH ADA
  await initializeDateFormatting('id_ID', null);
  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(ChatThreadAdapter());

  // ----- Firebase init -----
  await Firebase.initializeApp();

  // ----- Supabase init -----
  await Supabase.initialize(
    url: 'https://jqfqscorljutadkxwzwm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxZnFzY29ybGp1dGFka3h3endtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1MjUxODUsImV4cCI6MjA3OTEwMTE4NX0.Q-eJFGujkxcW8tlTRnlTgSEGJR7EzonHnx1KSi1jMFM',
  );

  await NotificationService.init();
  await FcmService.init();

  // THEME PROVIDER
  final themeProvider = await ThemeProvider.create();

  runApp(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00796B);
    const accentTeal = Color(0xFF4DB6AC);

    final themeProvider = context.watch<ThemeProvider>();

    final lightScheme = ColorScheme.fromSeed(
      seedColor: primaryTeal,
      primary: primaryTeal,
      secondary: accentTeal,
      brightness: Brightness.light,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: primaryTeal,
      primary: primaryTeal,
      secondary: accentTeal,
      brightness: Brightness.dark,
    );

    // ============= LIGHT THEME =============
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: const Color(0xFFE0F2F1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryTeal,
        selectionColor: Color(0xFFB2DFDB),
        selectionHandleColor: primaryTeal,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryTeal,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: primaryTeal, width: 2),
          foregroundColor: primaryTeal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Colors.grey),
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: primaryTeal,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: primaryTeal.withOpacity(0.4), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: primaryTeal, width: 1.6),
        ),
      ),
    );

    // ============= DARK THEME (HIJAU SOFT) =============
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,

      // background utama lebih terang, hijau gelap soft
      scaffoldBackgroundColor: const Color(0xFF263833),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF263833),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // teks default di dark mode
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentTeal,
        selectionColor: Color(0xFF3C5E57),
        selectionHandleColor: accentTeal,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentTeal,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: accentTeal, width: 2),
          foregroundColor: accentTeal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentTeal,
        ),
      ),

      // ⬇️ PENTING: Styling TextField di DARK MODE
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // warna isi textfield di dark
        fillColor: const Color(0xFF2F4842),
        hintStyle: const TextStyle(color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIconColor: accentTeal,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: accentTeal, width: 1.6),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CIHUY',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/pdf-quitline': (_) => const PdfViewerScreen(
              sourcePath:
                  'https://jqfqscorljutadkxwzwm.supabase.co/storage/v1/object/public/education-pdf/who/pelatihan_konselor_quitline.pdf',
              isAsset: false,
              title: 'Pelatihan Konselor Quitline',
            ),
        '/pdf-panduan-mulut': (_) => const PdfViewerScreen(
              sourcePath:
                  'https://jqfqscorljutadkxwzwm.supabase.co/storage/v1/object/public/education-pdf/who/panduan_berhenti_tembakau_penyakit_mulut.pdf',
              isAsset: false,
              title: 'Panduan Berhenti Tembakau (Penyakit Mulut)',
            ),
        '/pdf-integrasi-mulut': (_) => const PdfViewerScreen(
              sourcePath:
                  'https://jqfqscorljutadkxwzwm.supabase.co/storage/v1/object/public/education-pdf/who/integrasi_berhenti_merokok_kesehatan_mulut.pdf',
              isAsset: false,
              title: 'Integrasi Berhenti Merokok (Kesehatan Mulut)',
            ),
        '/pdf-laporan-who': (_) => const PdfViewerScreen(
              sourcePath:
                  'https://jqfqscorljutadkxwzwm.supabase.co/storage/v1/object/public/education-pdf/who/laporan_who_epidemi_tembakau_2019.pdf',
              isAsset: false,
              title: 'Laporan WHO Epidemi Tembakau 2019',
            ),
      },
    );
  }
}