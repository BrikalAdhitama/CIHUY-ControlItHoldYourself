import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';

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
    // ... (Logika _register sama persis, tidak ada perubahan) ...
    if (_emailController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _message = 'Semua field harus diisi');
      return;
    }
    setState(() { _isLoading = true; _message = ''; });

    final response = await AuthService.register(
      _emailController.text,
      _usernameController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (response['success']) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['message']), backgroundColor: Colors.green,
      ));
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() => _message = response['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // MENGGANTI IKON BACK DENGAN TEKS "Kembali"
        leadingWidth: 130, // Beri lebar cukup agar teks tidak terpotong
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Theme.of(context).primaryColorDark),
          label: Text(
            'Kembali',
            style: TextStyle(color: Theme.of(context).primaryColorDark, fontWeight: FontWeight.bold),
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
                    color: Theme.of(context).primaryColorDark,
                  ),
                ),
                const SizedBox(height: 50),
                CustomTextField(controller: _emailController, labelText: 'Masukkan email', prefixIcon: Icons.email_outlined),
                const SizedBox(height: 20),
                CustomTextField(controller: _usernameController, labelText: 'Masukkan username', prefixIcon: Icons.person_outline),
                const SizedBox(height: 20),

                // PASSWORD FIELD DENGAN TEKS "Tampilkan"
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
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Ukuran font sedikit diperkecil agar muat
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(_message, textAlign: TextAlign.center, style: TextStyle(color: _message.toLowerCase().contains('berhasil') ? Colors.green : Colors.red)),
                  ),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _register, child: const Text('Buat akun', style: TextStyle(fontSize: 18))),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}