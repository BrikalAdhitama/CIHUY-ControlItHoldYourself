import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';
import 'verify_screen.dart';

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

    final available =
        await AuthService.isUsernameAvailable(username);
    if (!available) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Username sudah digunakan.';
      });
      return;
    }

    final response =
        await AuthService.register(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyScreen(
            email: email,
            username: username,
          ),
        ),
      );
    } else {
      setState(() =>
          _message = response['message'] ?? 'Register gagal.');
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
          // ===== HEADER (SINGLE WAVE) =====
          ClipPath(
            clipper: SmoothWaveClipper(),
            child: Container(
              height: 230,
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
              child: Stack(
                children: [
                  // BACK BUTTON
                  Positioned(
                    top: 40,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // TITLE
                  const Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),

                      CustomTextField(
                        controller: _emailController,
                        labelText: 'Masukkan email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        controller: _usernameController,
                        labelText: 'Masukkan username',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        controller: _passwordController,
                        labelText: 'Masukkan password',
                        obscureText: !_isPasswordVisible,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: accentColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible =
                                  !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_message.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _message
                                      .toLowerCase()
                                      .contains('berhasil')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),

                      _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: accentColor),
                            )
                          : ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(30),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 15),
                              ),
                              child: const Text(
                                'Buat Akun',
                                style:
                                    TextStyle(fontSize: 18),
                              ),
                            ),
                      const SizedBox(height: 30),
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

/// ===== SINGLE SMOOTH WAVE (SAMA DENGAN LOGIN) =====
class SmoothWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);

    path.quadraticBezierTo(
      size.width * 0.5,
      size.height,
      size.width,
      size.height - 60,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
