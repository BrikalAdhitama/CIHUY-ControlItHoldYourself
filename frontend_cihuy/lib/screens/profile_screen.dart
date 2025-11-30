import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _avatarUrl;
  String? _email;
  DateTime? _quitDate;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // --- helper: hitung hari sejak berhenti ---
  int get _daysSinceQuit {
    if (_quitDate == null) return 0;
    return DateTime.now().difference(_quitDate!).inDays;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    final profile = await AuthService.getCurrentProfile();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (profile != null) {
        _avatarUrl = profile['avatar_url'] as String?;
        _email = profile['email'] as String?;
        if (profile['quit_date'] != null) {
          _quitDate = DateTime.tryParse(profile['quit_date']);
        }
      }
    });
  }

  Future<void> _changeAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked == null) return; // user batal

      setState(() => _isLoading = true);

      final url = await AuthService.uploadAvatar(picked.path);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (url != null) {
          _avatarUrl = url;
        }
      });

      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal upload foto profil')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101518) : const Color(0xFFE0F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: _isLoading && _avatarUrl == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2529) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar + tombol kamera
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : const Color(0xFFE0E0E0),
                            backgroundImage:
                                _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                            child: _avatarUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 62,
                                    color: isDark ? Colors.white70 : Colors.white,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: InkWell(
                              onTap: _isLoading ? null : _changeAvatar,
                              borderRadius: BorderRadius.circular(20),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    isDark ? Colors.teal[300] : const Color(0xFF00796B),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Username
                      Text(
                        widget.username,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),

                      // Email kalau ada
                      if (_email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Status "Pejuang Sehat" sebagai chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF80CBC4)),
                        ),
                        child: const Text(
                          'Status: Pejuang Sehat',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00796B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Info ringkas: hari bebas & tanggal berhenti
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            label: 'Hari Bebas',
                            value: _daysSinceQuit.toString(),
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            label: 'Berhenti Sejak',
                            value: _quitDate != null
                                ? '${_quitDate!.day.toString().padLeft(2, '0')}-'
                                  '${_quitDate!.month.toString().padLeft(2, '0')}-'
                                  '${_quitDate!.year}'
                                : '-',
                            isDark: isDark,
                            small: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // text kecil motivasi
                      Text(
                        'Terus pertahankan progresmu.\nSetiap hari tanpa nikotin itu kemenangan ✊',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required bool isDark,
    bool small = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: small ? 16 : 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF00796B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
