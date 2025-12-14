// lib/screens/help_screen.dart
import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF071012) : const Color(0xFFE0F2F1);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Bantuan & Info'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========================== //
          //           TENTANG           //
          // ========================== //
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tentang CIHUY',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CIHUY (Control it, Hold Yourself!) adalah aplikasi pendamping '
                  'untuk membantu kamu berhenti merokok dan vape dengan fitur seperti:\n'
                  '- Timer berhenti\n'
                  '- Catatan relapse\n'
                  '- Motivasi harian\n'
                  '- Kalender perjalanan lengkap\n'
                  '- Edukasi rokok dan vape',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: subTextColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ========================== //
          //          PANDUAN           //
          // ========================== //
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panduan Singkat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),

                _helpStep(
                  title: 'Timer Berhenti',
                  body: 'Tampilan utama menunjukkan berapa lama kamu sudah bebas '
                      'dari rokok atau vape.',
                  titleColor: textColor,
                  bodyColor: subTextColor,
                ),
                _helpStep(
                  title: 'Reset Timer (Relapse)',
                  body: 'Kalau kamu merokok/vape lagi, tekan tombol “Saya Merokok/Vape Lagi”, '
                      'isi jumlahnya, dan timer akan reset otomatis.',
                  titleColor: textColor,
                  bodyColor: subTextColor,
                ),
                _helpStep(
                  title: 'Riwayat Perjalanan',
                  body: 'Cek kalender lengkap perjalananmu: hari sukses ditandai hijau, '
                      'hari relapse ditandai merah.',
                  titleColor: textColor,
                  bodyColor: subTextColor,
                ),
                _helpStep(
                  title: 'Profil & Foto',
                  body: 'Kamu bisa ganti foto profil, nama, dan lihat status perkembanganmu.',
                  titleColor: textColor,
                  bodyColor: subTextColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ========================== //
          //       BANTUAN LANJUT       //
          // ========================== //
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Butuh Bantuan Lanjutan?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kalau kamu merasa kesulitan berhenti sendiri, kamu bisa konsultasi '
                  'ke tenaga kesehatan profesional atau layanan berhenti merokok di daerahmu.',
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
    );
  }

  // ===================================== //
  //          COMPONENT PANDUAN            //
  // ===================================== //
  Widget _helpStep({
    required String title,
    required String body,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}