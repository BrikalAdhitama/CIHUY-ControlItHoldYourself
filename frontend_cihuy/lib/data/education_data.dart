// lib/data/education_data.dart
class EducationItem {
  final String id;
  final String title;
  final String type; // 'article' or 'video'
  final String content; // for article (markdown)
  final String url; // for video (YouTube link)
  final List<String>? tags;

  EducationItem({
    required this.id,
    required this.title,
    required this.type,
    this.content = '',
    this.url = '',
    this.tags,
  });
}

/// Static data store (no DB). Add / edit here.
class EducationData {
  static final List<EducationItem> items = [
    // --- ARTICLES (examples) ---
    EducationItem(
      id: 'a-1',
      title: 'Bahaya Rokok untuk Kesehatan',
      type: 'article',
      content: '''
### Bahaya Rokok
Merokok meningkatkan risiko penyakit jantung, kanker paru-paru, stroke, dan berbagai penyakit kronis lainnya.

**Poin penting:**
- Nikotin bikin kecanduan.
- Zat karsinogen (kanker) ada ratusan.
- Dampak tidak hanya perokok — perokok pasif juga kena.
''',
      tags: ['bahaya', 'fakta'],
    ),
    EducationItem(
      id: 'a-2',
      title: 'Tips Praktis Mengurangi Keinginan Merokok',
      type: 'article',
      content: '''
### Tips singkat
1. Alihkan tangan/mulut (permen karet, minum air).
2. Catat pemicu kambuh & hindari pemicu itu sementara.
3. Pasang reward kecil setiap 24 jam sukses.
4. Cari teman yang support atau komunitas.

> Konsistensi kecil > tekad besar yang nggak ada rencana.
''',
      tags: ['tips', 'praktis'],
    ),

    // --- VIDEOS (you provided links) ---
    EducationItem(
      id: 'v-1',
      title: 'Video Edukasi 1',
      type: 'video',
      url: 'https://youtu.be/_WGPxucKKiQ?si=ANvzLrcGE8qm4geh',
      tags: ['video'],
    ),
    EducationItem(
      id: 'v-2',
      title: 'Video Edukasi 2',
      type: 'video',
      url: 'https://youtu.be/tRGAdtdn41E?si=rnijtWg5f0VHJcnQ',
      tags: ['video'],
    ),
    EducationItem(
      id: 'v-3',
      title: 'Video Edukasi 3',
      type: 'video',
      url: 'https://youtu.be/DB9n7aNM6q0?si=_9YhkmgpYIefUgAQ',
      tags: ['video'],
    ),
    EducationItem(
      id: 'v-4',
      title: 'Video Edukasi 4',
      type: 'video',
      url: 'https://youtu.be/VJEt9-sjZrM?si=1MSFr6R6d-3JjdsQ',
      tags: ['video'],
    ),
    EducationItem(
      id: 'v-5',
      title: 'Video Edukasi 5',
      type: 'video',
      url: 'https://youtu.be/o3I0mJ2RfU0?si=26fiQ4R_mPDwEc3a',
      tags: ['video'],
    ),
    EducationItem(
      id: 'v-6',
      title: 'Video Edukasi 6',
      type: 'video',
      url: 'https://youtu.be/Y18Vz51Nkos?si=EpYY7GEWdTE3JlKB',
      tags: ['video'],
    ),
    EducationItem(
      id: 'v-7',
      title: 'Video Edukasi 7',
      type: 'video',
      url: 'https://youtu.be/fLbQfMmrISE?si=czuX2JRP4anDqATh',
      tags: ['video'],
    ),
  ];

  static EducationItem? byId(String id) {
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<EducationItem> all() => List.unmodifiable(items);
}
