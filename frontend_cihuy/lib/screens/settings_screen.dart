import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String username;

  const SettingsScreen({super.key, required this.username});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kNotifPrefKey = 'pref_notif_enabled';

  bool _notifEnabled = false;
  bool _loadingNotifState = true;

  @override
  void initState() {
    super.initState();
    _loadNotifState();
  }

  Future<void> _loadNotifState() async {
    // initial state: combine persisted preference + actual permission status
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_kNotifPrefKey);

      // NotificationService.isEnabled() should reflect whether notifications are scheduled/enabled in app logic
      final serviceEnabled = await NotificationService.isEnabled();

      // Check system permission status
      final permissionStatus = await Permission.notification.status;

      final bool effectiveEnabled;
      if (stored != null) {
        // If user explicitly toggled in app before, prefer stored value but only enable if permission granted
        effectiveEnabled = stored && permissionStatus.isGranted && serviceEnabled;
      } else {
        // fallback: if service currently has scheduled notifications we consider enabled
        effectiveEnabled = permissionStatus.isGranted && serviceEnabled;
      }

      if (!mounted) return;
      setState(() {
        _notifEnabled = effectiveEnabled;
        _loadingNotifState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifEnabled = false;
        _loadingNotifState = false;
      });
    }
  }

  Future<void> _onToggleNotification(bool val) async {
    setState(() {
      _notifEnabled = val;
    });

    final prefs = await SharedPreferences.getInstance();

    if (val) {
      // User wants notifications ON
      final status = await Permission.notification.status;

      if (status.isGranted) {
        // we have permission → schedule
        await NotificationService.scheduleDaily8AM();
        await prefs.setBool(_kNotifPrefKey, true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengingat harian jam 08:00 diaktifkan')),
        );
      } else {
        // request permission
        final result = await Permission.notification.request();

        if (result.isGranted) {
          // granted now
          await NotificationService.scheduleDaily8AM();
          await prefs.setBool(_kNotifPrefKey, true);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Terima kasih, notifikasi aktif')),
          );
        } else if (result.isPermanentlyDenied) {
          // user permanently denied — cannot ask again; show dialog to open settings
          await prefs.setBool(_kNotifPrefKey, false);
          if (!mounted) return;
          _showOpenSettingsDialog();
        } else {
          // denied temporarily or restricted
          await prefs.setBool(_kNotifPrefKey, false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin notifikasi ditolak')),
          );
        }
      }
    } else {
      // User turned notifications OFF in app
      await NotificationService.cancel();
      await prefs.setBool(_kNotifPrefKey, false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengingat harian jam 08:00 dimatikan')),
      );
    }

    // refresh real state (in case permission changed externally)
    await _loadNotifState();
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izin dibutuhkan'),
        content: const Text(
          'Notifikasi diblokir. Silakan buka pengaturan aplikasi untuk mengizinkan notifikasi agar pengingat bisa berfungsi.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Nanti'),
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
          child: Icon(
            icon,
            color: const Color(0xFF00796B),
          ),
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
          // ===== AKUN =====
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

          // ===== PREFERENSI =====
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
            title: 'Pengingat Pagi 08:00',
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
                      // When toggled, manage permission + scheduling
                      await _onToggleNotification(val);
                    },
                  ),
          ),

          const SizedBox(height: 30),

          // ===== LAINNYA =====
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

          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Fitur hapus akun belum diimplementasikan.'),
                ),
              );
            },
            child: const Text(
              'Hapus Akun',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
