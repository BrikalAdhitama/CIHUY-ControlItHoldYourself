// lib/screens/education_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;

import 'pdf_viewer_screen.dart';

class EducationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const EducationDetailScreen({super.key, required this.item});

  @override
  State<EducationDetailScreen> createState() => _EducationDetailScreenState();
}

class _EducationDetailScreenState extends State<EducationDetailScreen> {
  YoutubePlayerController? _ytController;
  bool _ytReady = false;

  String _markdownRemote = '';
  bool _loadingMarkdown = false;

  // =======================
  // GETTER DATA DASAR
  // =======================

  String get _title =>
      (widget.item['title'] ?? 'Tanpa Judul').toString();

  String get _summary =>
      (widget.item['summary'] ?? '').toString();

  String get _contentFromDb =>
      (widget.item['content_markdown'] ?? '').toString();

  String get _updatedRaw =>
      (widget.item['updated_at'] ?? '').toString();

  String? get _videoUrl {
    final v = widget.item['video_url'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? get _pdfUrl {
    final v = widget.item['pdf_url'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// URL ke file .md di Supabase Storage
  String? get _markdownUrl {
    // support beberapa nama kolom biar ga rewel
    final candidates = ['markdown_url', 'md_url', 'md_link'];

    for (final key in candidates) {
      final v = widget.item[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  // =======================
  // INIT & DISPOSE
  // =======================

  @override
  void initState() {
    super.initState();

    // debug kalau perlu
    // debugPrint('ITEM DETAIL = ${widget.item}');
    // debugPrint('MARKDOWN URL = ${_markdownUrl}');

    // YouTube
    if (_videoUrl != null) {
      _initYoutube(_videoUrl!);
    }

    // Markdown dari Supabase Storage
    if (_markdownUrl != null) {
      _fetchMarkdownFromUrl(_markdownUrl!);
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  void _initYoutube(String url) {
    final id = YoutubePlayer.convertUrlToId(url);
    if (id == null || id.isEmpty) return;

    _ytController = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    )..addListener(() {
        if (!_ytReady && mounted) {
          setState(() {
            _ytReady = true;
          });
        }
      });
  }

  Future<void> _fetchMarkdownFromUrl(String url) async {
    setState(() => _loadingMarkdown = true);
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        _markdownRemote = res.body;
      } else {
        // kalau gagal, biarin aja fallback ke summary / content_markdown
      }
    } catch (_) {
      // diem aja, jangan bikin crash
    } finally {
      if (mounted) {
        setState(() => _loadingMarkdown = false);
      }
    }
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka link eksternal.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka link eksternal.')),
      );
    }
  }

  String _prettyDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return raw.split('T').first;
    }
  }

  // =======================
  // WIDGET VIDEO YT
  // =======================

  Widget _buildVideoArea() {
    final url = _videoUrl!;
    if (_ytController == null) {
      // gagal parse ID → tombol buka YouTube aja
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ondemand_video_outlined,
                  size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Tidak dapat menampilkan video di dalam aplikasi.'),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Buka di YouTube / Browser'),
                onPressed: () => _launchExternal(Uri.parse(url)),
              ),
            ],
          ),
        ),
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Column(
          children: [
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: player,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka di aplikasi eksternal'),
                  onPressed: () => _launchExternal(Uri.parse(url)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh video',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _ytController!.reload();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // =======================
  // WIDGET MARKDOWN
  // =======================

  Widget _buildMarkdownContent() {
    // Prioritas:
    // 1. markdown yang di-download dari URL
    // 2. content_markdown dari DB
    // 3. summary kalau dua-duanya kosong
    final md = _markdownRemote.isNotEmpty
        ? _markdownRemote
        : (_contentFromDb.isNotEmpty ? _contentFromDb : _summary);

    if (md.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Konten belum tersedia.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingMarkdown)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          MarkdownBody(
            data: md,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
              listBullet: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // =======================
  // BUILD
  // =======================

  @override
  Widget build(BuildContext context) {
    final updated = _prettyDate(_updatedRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_videoUrl != null)
            IconButton(
              icon: const Icon(Icons.ondemand_video),
              tooltip: 'Buka video di aplikasi eksternal',
              onPressed: () => _launchExternal(Uri.parse(_videoUrl!)),
            ),
          if (_pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Buka PDF',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      sourcePath: _pdfUrl!,
                      isAsset: false,
                      title: _title,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // HEADER
          Container(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (updated.isNotEmpty)
                  Text(
                    updated,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),

          // SUMMARY PENDEK
          if (_summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                _summary,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),

          const SizedBox(height: 8),

          // VIDEO (kalau ada)
          if (_videoUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: _buildVideoArea(),
            ),

          const SizedBox(height: 8),

          // PDF CARD (kalau ada)
          if (_pdfUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf,
                      color: Colors.redAccent),
                  title: const Text('Buka dokumen PDF'),
                  subtitle: Text(
                    Uri.parse(_pdfUrl!).path.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          sourcePath: _pdfUrl!,
                          isAsset: false,
                          title: _title,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 12),

          // MARKDOWN (MD artikel / long text)
          _buildMarkdownContent(),
        ],
      ),
    );
  }
}