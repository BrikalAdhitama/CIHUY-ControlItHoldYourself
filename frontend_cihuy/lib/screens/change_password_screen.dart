import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends State<ChangePasswordScreen> {
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

    // ===== VALIDASI =====
    if (oldPass.isEmpty ||
        newPass.isEmpty ||
        confirmPass.isEmpty) {
      setState(() => _error = 'Semua field wajib diisi.');
      return;
    }

    if (newPass.length < 6) {
      setState(
          () => _error = 'Password baru minimal 6 karakter.');
      return;
    }

    if (newPass == oldPass) {
      setState(() => _error =
          'Password baru tidak boleh sama dengan password lama.');
      return;
    }

    if (newPass != confirmPass) {
      setState(() =>
          _error = 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null || user.email == null) {
        setState(() {
          _loading = false;
          _error =
              'Session tidak valid. Silakan login ulang.';
        });
        return;
      }

      // ===== RE-AUTH =====
      final res = await supabase.auth.signInWithPassword(
        email: user.email!,
        password: oldPass,
      );

      if (res.user == null) {
        setState(() {
          _loading = false;
          _error = 'Password lama salah.';
        });
        return;
      }

      // ===== UPDATE PASSWORD =====
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
        _loading = false;
        _error = 'Gagal mengganti password. Coba lagi.';
      });
    }
  }

  Future<void> _confirmAndChangePassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ganti Password'),
          content: const Text(
            'Pastikan kamu mengingat password baru kamu.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(true),
              child: const Text(
                'Ganti',
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
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF121212) : Colors.white;
    final accent =
        isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00796B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Ganti Password'),
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ubah password akun kamu.',
                style: TextStyle(
                  color: isDark
                      ? Colors.grey[400]
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 30),

              // PASSWORD LAMA
              TextField(
                controller: _oldPass,
                obscureText: !_showOld,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon:
                      const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showOld
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showOld = !_showOld),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // PASSWORD BARU
              TextField(
                controller: _newPass,
                obscureText: !_showNew,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon:
                      const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNew
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showNew = !_showNew),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // KONFIRMASI PASSWORD
              TextField(
                controller: _confirmPass,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon:
                      const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                        () => _showConfirm = !_showConfirm),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_error.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error,
                    style:
                        const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 10),

              _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: accent),
                    )
                  : ElevatedButton(
                      onPressed:
                          _confirmAndChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Simpan Password',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
