import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _notifEnabled = false;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _checkNotifPermission();
  }

  Future<void> _checkNotifPermission() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _notifEnabled = status.isGranted;
      _loading = false;
    });
  }

  Future<void> _toggleNotif(bool value) async {
    setState(() => _loading = true);
    if (value) {
      final granted =
          await NotificationService.requestPermissions();
      if (!mounted) return;
      if (!granted) _openSettingsDialog();
    } else {
      _openSettingsDialog(turningOff: true);
    }
    await _checkNotifPermission();
    if (mounted) setState(() => _loading = false);
  }

  void _openSettingsDialog({bool turningOff = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:
            Text(turningOff ? 'Matikan Notifikasi' : 'Izin Dibutuhkan'),
        content: Text(
          turningOff
              ? 'Android tidak mengizinkan aplikasi mematikan notifikasi sendiri.\n\nSilakan matikan lewat pengaturan HP.'
              : 'Notifikasi diblokir.\n\nSilakan izinkan lewat pengaturan aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Hapus Akun?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Semua data Anda akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    final ok = await AuthService.deleteAccount();

    if (!mounted) return;
    setState(() => _deleting = false);

    if (ok) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus akun')),
      );
    }
  }

  // ===== SECTION CARD =====
  Widget _buildSectionCard(
      BuildContext context, String title, List<Widget> children) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor =
        isDark ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: cardColor,
          child: Column(children: children),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    // ===== WARNA CIHUY =====
    const primaryColor = Color(0xFF00796B);
    const cihuyBg = Color(0xFFE0F2F1);

    final bgColor =
        isDark ? const Color(0xFF121212) : cihuyBg;
    final textColor =
        isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildSectionCard(
            context,
            'AKUN',
            [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: primaryColor,
                  child:
                      Icon(Icons.person_outline, color: Colors.white),
                ),
                title: const Text('Profil Saya'),
                subtitle: Text(widget.username),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(username: widget.username),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: primaryColor,
                  child:
                      Icon(Icons.lock_outline, color: Colors.white),
                ),
                title: const Text('Ganti Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ChangePasswordScreen(),
                  ),
                ),
              ),
            ],
          ),
          _buildSectionCard(
            context,
            'PREFERENSI',
            [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade400,
                  child: const Icon(Icons.dark_mode_outlined,
                      color: Colors.white),
                ),
                title: const Text('Tema Gelap'),
                trailing: Switch(
                  value: theme.isDarkMode,
                  onChanged: theme.toggleTheme,
                  activeColor: primaryColor,
                ),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade600,
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.white,
                  ),
                ),
                title: const Text('Notifikasi Pengingat'),
                subtitle:
                    Text(_notifEnabled ? 'Aktif' : 'Nonaktif'),
                trailing: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : Switch(
                        value: _notifEnabled,
                        onChanged: _toggleNotif,
                        activeColor: primaryColor,
                      ),
              ),
            ],
          ),
          _buildSectionCard(
            context,
            'LAINNYA',
            [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child:
                      Icon(Icons.info_outline, color: Colors.white),
                ),
                title: const Text('Tentang Aplikasi'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'CIHUY',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.info_outline,
                      size: 50, color: primaryColor),
                  applicationLegalese:
                      'Pendamping berhenti merokok & vape.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              color: Colors.red.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    BorderSide(color: Colors.red.withOpacity(0.3)),
              ),
              child: InkWell(
                onTap: _deleting ? null : _deleteAccount,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _deleting
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.red),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.delete_forever,
                                color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Hapus Akun',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
