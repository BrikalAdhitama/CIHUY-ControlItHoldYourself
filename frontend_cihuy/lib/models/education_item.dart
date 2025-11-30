// lib/models/education_item.dart
class EducationItem {
  final String id;
  final String title;
  final String summary;

  /// Optional: path markdown di assets, misal:
  /// 'assets/education/Manfaat_Berhenti_Merokok.md'
  final String? markdownAsset;

  /// Optional: kalau nanti mau tetap pakai video / pdf Supabase
  final String? videoUrl;
  final String? pdfUrl;

  const EducationItem({
    required this.id,
    required this.title,
    required this.summary,
    this.markdownAsset,
    this.videoUrl,
    this.pdfUrl,
  });

  /// Kalau suatu saat mau tetep ambil dari Supabase (table education)
  factory EducationItem.fromSupabase(Map<String, dynamic> row) {
    String? _clean(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return EducationItem(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? 'Tanpa Judul').toString(),
      summary: (row['summary'] ?? '').toString(),
      videoUrl: _clean(row['video_url']),
      pdfUrl: _clean(row['pdf_url']),
      markdownAsset: _clean(row['markdown_asset']),
    );
  }
}