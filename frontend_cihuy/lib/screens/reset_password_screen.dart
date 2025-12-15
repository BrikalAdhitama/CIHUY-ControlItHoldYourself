import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _resetPassword() async {
    if (_otpController.text.isEmpty || _newPasswordController.text.isEmpty) return;

    setState(() => _isLoading = true);

    // 1. Verifikasi Kode dulu (Ini akan otomatis meloginkan user sementara)
    final verifyRes = await AuthService.verifyRecoveryOtp(widget.email, _otpController.text);

    if (verifyRes['success']) {
      // 2. Jika kode benar, update password
      bool updateSuccess = await AuthService.updatePassword(_newPasswordController.text);
      
      setState(() => _isLoading = false);

      if (updateSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diubah! Silakan login.'), backgroundColor: Colors.green),
        );
        // Kembali ke halaman Login utama (hapus semua rute)
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui password.'), backgroundColor: Colors.red),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(verifyRes['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
    Widget build(BuildContext context) {
      // 1. Cek Tema HP (Gelap / Terang)
      final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        // [FIX COLOR] 
        // Kalau Dark Mode -> Hitam (0xFF121212)
        // Kalau Light Mode -> Biru Muda Teal (0xFFE0F2F1) kayak halaman Lupa Password
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFE0F2F1),

        appBar: AppBar(
          title: Text(
            "Atur Ulang Password",
            style: TextStyle(
              // Teks Putih di Dark Mode, Hitam di Light Mode
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent, // Transparan biar background Scaffold kelihatan
          elevation: 0,
          // Ikon Back Putih di Dark Mode, Hitam di Light Mode
          iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            children: [
              Text(
                "Masukkan kode dari email dan password baru Anda.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Warna teks instruksi menyesuaikan background
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 35),

              // Input OTP
              CustomTextField(
                controller: _otpController,
                labelText: "Kode 6 Digit",
                prefixIcon: Icons.vpn_key_outlined,
                keyboardType: TextInputType.number,
                // Pastikan CustomTextField-mu backgroundnya 'putih' atau 'transparan' 
                // biar bagus di atas warna biru muda ini.
              ),
              const SizedBox(height: 20),

              // Input Password Baru
              CustomTextField(
                controller: _newPasswordController,
                labelText: "Password Baru",
                prefixIcon: Icons.lock_outline,
                obscureText: _isObscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
              const SizedBox(height: 40),

              // Tombol Hijau
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF00796B))
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Simpan Password Baru",
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
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