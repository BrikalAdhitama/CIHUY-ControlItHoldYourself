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
  final TextEditingController _newPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _resetPassword() async {
    if (_otpController.text.isEmpty ||
        _newPasswordController.text.isEmpty) return;

    setState(() => _isLoading = true);

    // 1. Verifikasi OTP
    final verifyRes = await AuthService.verifyRecoveryOtp(
      widget.email,
      _otpController.text,
    );

    if (verifyRes['success']) {
      // 2. Update password
      bool updateSuccess =
          await AuthService.updatePassword(
              _newPasswordController.text);

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (updateSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Password berhasil diubah! Silakan login.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui password.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verifyRes['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFE0F2F1);

    final accentColor =
        isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00796B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ===== HEADER WAVE =====
          ClipPath(
            clipper: WaveClipper(),
            child: Container(
              height: 170,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00796B),
                    Color(0xFF4DB6AC),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Atur Ulang Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Kembali',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== FORM =====
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Masukkan kode dari email dan password baru Anda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // OTP
                      CustomTextField(
                        controller: _otpController,
                        labelText: 'Kode 6 Digit',
                        prefixIcon:
                            Icons.vpn_key_outlined,
                        keyboardType:
                            TextInputType.number,
                      ),
                      const SizedBox(height: 20),

                      // Password Baru
                      CustomTextField(
                        controller:
                            _newPasswordController,
                        labelText: 'Password Baru',
                        prefixIcon:
                            Icons.lock_outline,
                        obscureText: _isObscure,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() {
                            _isObscure = !_isObscure;
                          }),
                        ),
                      ),
                      const SizedBox(height: 40),

                      _isLoading
                          ? Center(
                              child:
                                  CircularProgressIndicator(
                                      color:
                                          accentColor),
                            )
                          : ElevatedButton(
                              onPressed: _resetPassword,
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    accentColor,
                                foregroundColor:
                                    Colors.white,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          30),
                                ),
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        vertical:
                                            15),
                              ),
                              child: const Text(
                                'Simpan Password Baru',
                                style: TextStyle(
                                    fontSize: 16),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== WAVE CLIPPER =====
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
