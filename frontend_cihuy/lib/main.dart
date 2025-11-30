// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/chat_message.dart';
import 'models/chat_thread.dart';
import 'models/hive_adapters.dart'; // <-- IMPORTANT: register adapters are here
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/pdf_viewer_screen.dart'; // <-- TAMBAH INI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -------------------------
  // Hive init + register adapters
  // -------------------------
  await Hive.initFlutter();

  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(ChatThreadAdapter());

  // -------------------------
  // Supabase init
  // -------------------------
  await Supabase.initialize(
    url: 'https://jqfqscorljutadkxwzwm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxZnFzY29ybGp1dGFka3h3endtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1MjUxODUsImV4cCI6MjA3OTEwMTE4NX0.Q-eJFGujkxcW8tlTRnlTgSEGJR7EzonHnx1KSi1jMFM',
  );

  // -------------------------
  // Notification init
  // -------------------------
  await NotificationService.init();

  // -------------------------
  // INIT LOCALE UNTUK DateFormat('id_ID')
  // -------------------------
  await initializeDateFormatting('id_ID', null);

  // -------------------------
  // Run app wrapped with Provider
  // -------------------------
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentTeal,
        selectionColor: Color(0xFF004D40),
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