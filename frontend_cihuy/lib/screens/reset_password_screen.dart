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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Atur Ulang Password", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const Text("Masukkan kode dari email dan password baru Anda.", textAlign: TextAlign.center),
            const SizedBox(height: 30),
            
            // Input OTP
            CustomTextField(
              controller: _otpController,
              labelText: "Kode 6 Digit",
              prefixIcon: Icons.lock_clock,
            ),
            const SizedBox(height: 20),

            // Input Password Baru
            CustomTextField(
              controller: _newPasswordController,
              labelText: "Password Baru",
              prefixIcon: Icons.lock,
              obscureText: _isObscure,
              suffixIcon: IconButton(
                icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ),
            ),
            const SizedBox(height: 30),

            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text("Simpan Password Baru", style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}