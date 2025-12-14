// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Tidak wajib lagi, tapi kalau mau dipakai boleh

import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String username;

  const SettingsScreen({super.key, required this.username});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // static const _kNotifPrefKey = 'pref_notif_enabled'; // Tidak perlu simpan pref manual, ikut izin HP aja

  bool _notifEnabled = false;
  bool _loadingNotifState = true;
  bool _processingToggle = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadNotifState();
  }

  // --- PERBAIKAN 1: Cek status notifikasi murni dari Izin HP ---
  Future<void> _loadNotifState() async {
    try {
      // Kita cukup cek apakah user mengizinkan notifikasi di HP-nya
      final status = await Permission.notification.status;
      
      if (!mounted) return;
      setState(() {
        _notifEnabled = status.isGranted;
        _loadingNotifState = false;
      });
    } catch (e) {
      debugPrint('[Settings] _loadNotifState error: $e');
      if (!mounted) return;
      setState(() {
        _loadingNotifState = false;
      });
    }
  }

  // --- PERBAIKAN 2: Toggle hanya mengurus Izin (Tanpa Jadwal Lokal) ---
  Future<void> _onToggleNotification(bool val) async {
    if (_processingToggle) return;

    setState(() {
      _processingToggle = true;
    });

    try {
      if (val) {
        // User mau NYALAIN -> Minta Izin ke OS
        // Panggil fungsi request dari NotificationService yang sudah kita fix
        final granted = await NotificationService.requestPermissions();
        
        if (granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifikasi diaktifkan! Menunggu pesan dari server...')),
          );
        } else {
          // Kalau ditolak, suruh buka settings manual
          if (!mounted) return;
          _showOpenSettingsDialog();
        }
      } else {
        // User mau MATIIN -> Android modern tidak izinkan aplikasi matikan izin sendiri
        // Jadi kita arahkan ke settings HP
        if (!mounted) return;
        _showOpenSettingsDialog(isTurningOff: true);
        
        // Opsional: Bersihkan notif yang lagi nampil di layar
        await NotificationService.cancelAll();
      }
    } catch (e) {
      debugPrint('Error toggle: $e');
    } finally {
      // Refresh status terakhir
      await _loadNotifState();
      if (mounted) {
        setState(() {
          _processingToggle = false;
        });
      }
    }
  }

  void _showOpenSettingsDialog({bool isTurningOff = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTurningOff ? 'Matikan Notifikasi' : 'Izin Dibutuhkan'),
        content: Text(
          isTurningOff
              ? 'Aplikasi tidak bisa mematikan izin secara otomatis. Silakan matikan manual di Pengaturan.'
              : 'Notifikasi diblokir. Silakan buka pengaturan aplikasi untuk mengizinkan notifikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(ctx);
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  // ========= HAPUS AKUN (TETAP SAMA) =========
  Future<void> _confirmDeleteAccount() async {
    if (_isDeletingAccount) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun?'),
        content: const Text(
          'Akun kamu, riwayat perjalanan, dan data terkait akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.\n\nYakin banget mau lanjut?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _isDeletingAccount = true);

    final success = await AuthService.deleteAccount();

    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun berhasil dihapus.')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus akun. Coba lagi sebentar lagi.'),
        ),
      );
    }
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color cardColor,
    required Color textColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF00796B)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    const primaryTeal = Color(0xFF00796B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Akun',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _buildSettingsTile(
            context: context,
            icon: Icons.person_outline,
            title: 'Profil Saya',
            cardColor: cardColor,
            textColor: textColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(username: widget.username),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.lock_outline,
            title: 'Ganti Password',
            cardColor: cardColor,
            textColor: textColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 30),

          const Text(
            'Preferensi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          _buildSettingsTile(
            context: context,
            icon: Icons.dark_mode_outlined,
            title: 'Tema Gelap',
            cardColor: cardColor,
            textColor: textColor,
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (val) {
                themeProvider.toggleTheme(val);
              },
              activeColor: const Color(0xFF4DB6AC),
            ),
          ),

          _buildSettingsTile(
            context: context,
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi Pengingat',
            cardColor: cardColor,
            textColor: textColor,
            trailing: _loadingNotifState
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: _notifEnabled,
                    activeColor: primaryTeal,
                    onChanged: (val) async {
                      await _onToggleNotification(val);
                    },
                  ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Lainnya',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _buildSettingsTile(
            context: context,
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            cardColor: cardColor,
            textColor: textColor,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'CIHUY',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    'Aplikasi pendamping berhenti merokok & vape.',
              );
            },
          ),

          const SizedBox(height: 30),

          Center(
            child: _isDeletingAccount
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  )
                : TextButton(
                    onPressed: _confirmDeleteAccount,
                    child: const Text(
                      'Hapus Akun',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}