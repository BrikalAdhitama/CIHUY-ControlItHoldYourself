// lib/screens/pdf_education_screen.dart
import 'package:flutter/material.dart';
import 'pdf_viewer_screen.dart';

class PdfEducationScreen extends StatelessWidget {
  const PdfEducationScreen({super.key});

  // BASE URL YANG BENAR (kxwzwm)
  static const String _base =
      'https://jqfqscorljutadkxwzwm.supabase.co/storage/v1/object/public/education-pdf/who';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Materi WHO – Berhenti Merokok"),
      ),
      body: ListView(
        children: [
          _buildItem(
            context,
            title: "Pelatihan Konselor Quitline",
            file: "pelatihan_konselor_quitline.pdf",
          ),
          _buildItem(
            context,
            title: "Panduan Berhenti Tembakau (Penyakit Mulut)",
            file: "panduan_berhenti_tembakau_penyakit_mulut.pdf",
          ),
          _buildItem(
            context,
            title: "Integrasi Berhenti Merokok – Kesehatan Mulut",
            file: "integrasi_berhenti_merokok_kesehatan_mulut.pdf",
          ),
          _buildItem(
            context,
            title: "Laporan WHO Epidemi Tembakau 2019",
            file: "laporan_who_epidemi_tembakau_2019.pdf",
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String title,
    required String file,
  }) {
    final fullUrl = '$_base/$file';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                sourcePath: fullUrl,
                isAsset: false,
                title: title,
              ),
            ),
          );
        },
      ),
    );
  }
}