// lib/screens/profile_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;

  String? _displayName;
  String? _email;
  String? _avatarUrl;
  String? _username; // username login yang tetap ditampilkan

  DateTime? _quitDate; // lokal
  int _freeDays = 0;

  String _statusLabel = 'Pejuang Sehat';
  Color _statusColor = const Color(0xFF00796B).withOpacity(0.12);
  Color _statusTextColor = const Color(0xFF00796B);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    final data = await AuthService.getCurrentProfile();
    final quit = await AuthService.getQuitDate();

    String? name = widget.username;
    String? email;
    String? avatarUrl;
    String? username;

    if (data != null) {
      username = data['username'] as String?;

      // pakai display_name kalau ada, kalau tidak fallback ke username
      final displayName = data['display_name'] as String?;
      name = displayName ?? username ?? name;

      email = data['email'] as String?;
      avatarUrl = data['avatar_url'] as String?;
    }

    int freeDays = 0;
    if (quit != null) {
      final now = DateTime.now();
      final quitLocal =
          DateTime(quit.year, quit.month, quit.day); // buang jam
      final diff = now.difference(quitLocal);
      freeDays = diff.inDays < 0 ? 0 : diff.inDays;
    }

    setState(() {
      _username = username ?? widget.username;
      _displayName = name ?? widget.username;
      _email = email;
      _avatarUrl = avatarUrl;
      _quitDate = quit;
      _freeDays = freeDays;
      _loading = false;

      if (_freeDays >= 30) {
        _statusLabel = 'Pemenang Nikotin';
      } else if (_freeDays >= 7) {
        _statusLabel = 'Pejuang Tangguh';
      } else {
        _statusLabel = 'Pejuang Sehat';
      }
    });
  }

  /// Versi SIMPLE: pilih foto → langsung upload ke Supabase (tanpa crop)
  Future<void> _pickAndUploadAvatar() async {
    // 1. pilih gambar dari gallery
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 90,
    );

    if (picked == null) return; // user cancel

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mengupload foto profil...')),
    );

    final file = File(picked.path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File gambar tidak ditemukan di perangkat.')),
      );
      return;
    }

    // 2. upload ke Supabase via AuthService
    final result = await AuthService.uploadAvatar(picked.path);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success'] == true) {
      final url = result['url'] as String?;
      if (url != null) {
        setState(() {
          _avatarUrl = url;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
      );
    } else {
      final msg = (result['message'] ?? 'Gagal mengupload foto profil.') as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }


  Future<void> _showChangeNameDialog() async {
    final controller = TextEditingController(
      text: _displayName ?? widget.username,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Nama Tampilan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nama baru',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await AuthService.updateDisplayName(result);
      if (!mounted) return;

      if (success) {
        setState(() {
          _displayName = result;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama berhasil diperbarui')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui nama')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF071012) : const Color(0xFFE0F2F1);
    final cardColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];

    final quitText =
        _quitDate != null ? DateFormat('dd-MM-yyyy').format(_quitDate!) : '-';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        title: Text(
          'Profil Saya',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar + tombol kamera
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              backgroundImage: _avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 56,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[500],
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: InkWell(
                                onTap: _pickAndUploadAvatar,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00796B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _displayName ?? widget.username,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_email != null)
                          Text(
                            _email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: subTextColor,
                            ),
                          ),
                        if (_username != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Username: $_username',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showChangeNameDialog,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Ganti Nama Tampilan'),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Status: $_statusLabel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _statusTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              title: 'Hari Bebas',
                              value: _freeDays.toString(),
                              textColor: textColor,
                              isDark: isDark,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            _buildStatItem(
                              title: 'Berhenti Sejak',
                              value: quitText,
                              textColor: textColor,
                              isDark: isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Terus pertahankan progresmu.\nSetiap hari tanpa nikotin itu kemenangan ✊',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required Color textColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF00796B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}