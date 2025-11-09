import 'package:flutter/material.dart';
import 'package:frontend_cihuy/screens/login_screen.dart';
import 'package:frontend_cihuy/screens/register_screen.dart';
import 'package:frontend_cihuy/screens/home_screen.dart';

void main() {
  runApp(const CiHuyApp());
}

class CiHuyApp extends StatelessWidget {
  const CiHuyApp({super.key});

  // Ini adalah warna utama dari desain Anda
  static const Color primaryColor = Color(0xFF4DB6AC);
  static const Color primaryColorDark = Color(0xFF00796B);
  static const Color backgroundColor = Color(0xFFE0F7FA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIHUY!',
      theme: ThemeData(
        scaffoldBackgroundColor: backgroundColor, // Warna background utama
        primaryColor: primaryColor,
        fontFamily: 'Poppins', // (Pastikan Anda menambahkan font ini di assets nanti)
        
        // Tema untuk TextButton (Lupa Password)
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColorDark,
          ),
        ),
        
        // Tema untuk OutlinedButton (Buat Akun)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: primaryColor, width: 2),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),

        // Tema untuk ElevatedButton (Login)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        )
      ),
      debugShowCheckedModeBanner: false,
      
      // Halaman awal adalah login
      initialRoute: '/login',

      // Daftar semua halaman
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}