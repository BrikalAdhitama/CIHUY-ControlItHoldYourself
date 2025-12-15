import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendCode() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);

    bool success = await AuthService.sendPasswordResetEmail(_emailController.text);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode dikirim! Cek email Anda.'),
          backgroundColor: Color(0xFF00796B), // Hijau konsisten
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: _emailController.text),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengirim kode. Cek email Anda.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Cek Tema
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 2. Background Konsisten (Biru Muda di Light, Hitam di Dark)
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFE0F2F1),

      appBar: AppBar(
        title: Text(
          "Lupa Password",
          style: TextStyle(
            // Warna Teks menyesuaikan background
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // Transparan biar nyatu
        elevation: 0, // Hilangkan bayangan garis
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Konten di tengah vertikal
          children: [
            Text(
              "Masukkan email Anda yang terdaftar.\nKami akan mengirimkan kode pemulihan.",
              textAlign: TextAlign.center,
              style: TextStyle(
                // Warna teks instruksi menyesuaikan
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 35),

            CustomTextField(
              controller: _emailController,
              labelText: "Email",
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              // Pastikan CustomTextField backgroundnya putih/netral di light mode
            ),

            const SizedBox(height: 30),

            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF00796B))
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _sendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B), // Hijau Brand
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Kirim Kode",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}