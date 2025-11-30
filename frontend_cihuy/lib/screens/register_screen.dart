import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';
import 'verify_screen.dart'; // <-- PENTING: Import Verify Screen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _message = '';
  bool _isPasswordVisible = false;

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    // 1. Validasi basic
    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _message = 'Semua field harus diisi');
      return;
    }

    if (username.length < 3) {
      setState(() => _message = 'Username minimal 3 karakter');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    // 2. CEK USERNAME SUDAH DIPAKAI ATAU BELUM
    final available = await AuthService.isUsernameAvailable(username);
    if (!available) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Username sudah digunakan, coba yang lain.';
      });
      return;
    }

    // 3. Kalau aman → lanjut kirim OTP (register ke Supabase Auth)
    final response = await AuthService.register(
      email,
      password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['success'] == true) {
      // Tampilkan pesan sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.green,
        ),
      );

      // Pindah ke Verify Screen sambil MEMBAWA data Username
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyScreen(
            email: email,
            username: username, // Username dikirim lewat sini
          ),
        ),
      );
    } else {
      // Tampilkan pesan error
      setState(() => _message = response['message'] ?? 'Register gagal.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logika Warna (Dark/Light Mode)
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDarkMode ? Colors.white : const Color(0xFF00796B);
    final accentColor =
        isDarkMode ? const Color(0xFF4DB6AC) : const Color(0xFF00796B);
    final bgColor =
        isDarkMode ? const Color(0xFF121212) : const Color(0xFFE0F2F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 130,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: accentColor,
          ),
          label: Text(
            'Kembali',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CIHUY!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 50),

                // Input Email
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Masukkan email',
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                // Input Username
                CustomTextField(
                  controller: _usernameController,
                  labelText: 'Masukkan username',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 20),

                // Input Password
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Masukkan password',
                  obscureText: !_isPasswordVisible,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: TextButton(
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    child: Text(
                      _isPasswordVisible ? 'Sembunyikan' : 'Tampilkan',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Pesan Error / Info
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message.toLowerCase().contains('berhasil')
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),

                // Tombol Daftar
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Buat akun',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}