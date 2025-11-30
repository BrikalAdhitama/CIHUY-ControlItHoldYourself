import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  bool _loading = false;
  String _error = '';

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  Future<void> _changePassword() async {
    final oldPass = _oldPass.text.trim();
    final newPass = _newPass.text.trim();
    final confirmPass = _confirmPass.text.trim();

    // ===== VALIDASI DASAR =====
    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _error = 'Semua field wajib diisi.');
      return;
    }

    if (newPass.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter.');
      return;
    }

    if (newPass == oldPass) {
      setState(() => _error = 'Password baru tidak boleh sama dengan password lama.');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _error = 'Konfirmasi password baru tidak sama.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null || currentUser.email == null) {
        setState(() {
          _loading = false;
          _error = 'Session login tidak valid. Silakan login ulang.';
        });
        return;
      }

      // ===== RE-AUTH: cek password lama =====
      final res = await supabase.auth.signInWithPassword(
        email: currentUser.email!,
        password: oldPass,
      );

      if (res.user == null) {
        setState(() {
          _loading = false;
          _error = 'Password lama salah.';
        });
        return;
      }

      // ===== UPDATE PASSWORD BARU =====
      await supabase.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diganti.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal mengganti password. Coba lagi nanti.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndChangePassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yakin mau ganti password?'),
          content: const Text(
            'Setelah password diganti, pastikan kamu ingat password baru kamu ya.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Ya, ganti',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _changePassword();
    }
  }

  @override
  void dispose() {
    _oldPass.dispose();
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00796B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganti Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _oldPass,
                obscureText: !_showOld,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showOld ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() {
                      _showOld = !_showOld;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _newPass,
                obscureText: !_showNew,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() {
                      _showNew = !_showNew;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmPass,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() {
                      _showConfirm = !_showConfirm;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 10),
              _loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmAndChangePassword,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Simpan Password',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
