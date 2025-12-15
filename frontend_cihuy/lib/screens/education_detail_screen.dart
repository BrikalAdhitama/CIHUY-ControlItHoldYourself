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
  // GETTER DATA
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

  String? get _markdownUrl {
    final candidates = ['markdown_url', 'md_url', 'md_link'];
    for (final key in candidates) {
      final v = widget.item[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
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

    if (_videoUrl != null) {
      _initYoutube(_videoUrl!);
    }

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
    if (id == null) return;

    _ytController = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    )..addListener(() {
        if (!_ytReady && mounted) {
          setState(() => _ytReady = true);
        }
      });
  }

  Future<void> _fetchMarkdownFromUrl(String url) async {
    setState(() => _loadingMarkdown = true);
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        _markdownRemote = res.body;
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingMarkdown = false);
    }
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka link')),
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
  // VIDEO
  // =======================

  Widget _buildVideoArea() {
    final url = _videoUrl!;
    if (_ytController == null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka Video'),
            onPressed: () => _launchExternal(Uri.parse(url)),
          ),
        ),
      );
    }

    return YoutubePlayer(
      controller: _ytController!,
      showVideoProgressIndicator: true,
    );
  }

  // =======================
  // MARKDOWN
  // =======================

  Widget _buildMarkdownContent() {
    final md = _markdownRemote.isNotEmpty
        ? _markdownRemote
        : (_contentFromDb.isNotEmpty ? _contentFromDb : _summary);

    if (md.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Konten belum tersedia'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          if (_loadingMarkdown)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          MarkdownBody(
            data: md,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final updated = _prettyDate(_updatedRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_videoUrl != null)
            IconButton(
              icon: const Icon(Icons.ondemand_video),
              onPressed: () => _launchExternal(Uri.parse(_videoUrl!)),
            ),
          if (_pdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),

          // ================= FIXED SUMMARY =================
          if (_summary.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
              ),
            ),

          const SizedBox(height: 8),

          if (_videoUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildVideoArea(),
            ),

          const SizedBox(height: 12),

          if (_pdfUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf,
                      color: Colors.redAccent),
                  title: const Text('Buka dokumen PDF'),
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
          _buildMarkdownContent(),
        ],
      ),
    );
  }
}
