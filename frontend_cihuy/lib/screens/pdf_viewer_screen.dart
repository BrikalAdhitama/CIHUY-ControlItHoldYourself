// lib/screens/pdf_viewer_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

/// PdfViewerScreen
/// - sourcePath :
///    * isAsset == true  -> asset path, ex: 'assets/pdfs/file.pdf'
///    * isAsset == false -> bisa:
///         - full HTTP(S) URL (Supabase, dll)
///         - atau absolute local file path
/// - isAsset    : true kalau file dari assets
/// - title      : judul di AppBar (opsional)
class PdfViewerScreen extends StatefulWidget {
  final String sourcePath;
  final bool isAsset;
  final String? title;

  const PdfViewerScreen({
    Key? key,
    required this.sourcePath,
    this.isAsset = false,
    this.title,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with WidgetsBindingObserver {
  String? _localFilePath;
  bool _loading = true;
  int _pages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfController;
  bool _errorLoading = false;

  static const String _wrongDomain = 'jqfqscorljutadlkovzwm.supabase.co';
  static const String _correctDomain = 'jqfqscorljutadkxwzwm.supabase.co';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _errorLoading = false;
      _pages = 0;
      _currentPage = 0;
    });

    try {
      // --- NORMALISASI / AUTO-FIX DOMAIN DULU ---
      String path = widget.sourcePath.trim();

      if (path.contains(_wrongDomain)) {
        path = path.replaceAll(_wrongDomain, _correctDomain);
        debugPrint('FIXED OLD DOMAIN -> $path');
      }

      final isUrl = path.startsWith('http://') || path.startsWith('https://');

      if (widget.isAsset && !isUrl) {
        // ====== MODE ASSET ======
        final bytes = await rootBundle.load(path);
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${path.split('/').last}',
        );
        await file.writeAsBytes(bytes.buffer.asUint8List());
        _localFilePath = file.path;
      } else if (isUrl) {
        // ====== MODE URL (Supabase, dll) ======
        final uri = Uri.parse(path);
        final resp = await http.get(uri);

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final dir = await getTemporaryDirectory();
          final fileName =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'doc.pdf';

          // overwrite biar gak numpuk file
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(resp.bodyBytes, flush: true);
          _localFilePath = file.path;
        } else {
          _errorLoading = true;
          _showSnack('HTTP error: ${resp.statusCode}');
        }
      } else {
        // ====== MODE FILE LOKAL ======
        _localFilePath = path;
        if (!File(_localFilePath!).existsSync()) {
          _errorLoading = true;
        }
      }
    } catch (e) {
      _errorLoading = true;
      _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? widget.sourcePath.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Buka di luar',
            icon: const Icon(Icons.open_in_new),
            onPressed: _localFilePath == null ? null : _openExternal,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorLoading || _localFilePath == null
              ? _buildError()
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          PDFView(
                            filePath: _localFilePath!,
                            enableSwipe: true,
                            swipeHorizontal: false,
                            autoSpacing: true,
                            pageFling: true,
                            onRender: (pages) {
                              setState(() {
                                _pages = pages ?? 0;
                              });
                            },
                            onViewCreated: (controller) {
                              _pdfController = controller;
                            },
                            onPageChanged: (page, total) {
                              setState(() {
                                _currentPage = page ?? 0;
                                _pages = total ?? _pages;
                              });
                            },
                            onError: (error) {
                              setState(() {
                                _errorLoading = true;
                              });
                              _showSnack(
                                'Gagal membuka PDF: ${error.toString()}',
                              );
                            },
                            onPageError: (page, error) {
                              _showSnack(
                                'Error di halaman ${page ?? '?'}: ${error.toString()}',
                              );
                            },
                          ),
                          if (_loading)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text('Gagal memuat PDF.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Sumber: ${widget.sourcePath}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              onPressed: _prepare,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = _pages;
    final current = _currentPage + 1; // 1-based

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Halaman sebelumnya',
            icon: const Icon(Icons.chevron_left),
            onPressed: _pdfController == null || _pages == 0
                ? null
                : () {
                    final target =
                        (_currentPage - 1).clamp(0, _pages - 1);
                    _pdfController?.setPage(target);
                  },
          ),
          Text(
            '$current / $total',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Halaman selanjutnya',
            icon: const Icon(Icons.chevron_right),
            onPressed: _pdfController == null || _pages == 0
                ? null
                : () {
                    final target =
                        (_currentPage + 1).clamp(0, _pages - 1);
                    _pdfController?.setPage(target);
                  },
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Pergi ke halaman...',
            icon: const Icon(Icons.bookmarks),
            onPressed: _pages == 0
                ? null
                : () async {
                    final goTo =
                        await _askGotoPageDialog(context, _pages);
                    if (goTo != null && goTo > 0 && goTo <= _pages) {
                      _pdfController?.setPage(goTo - 1);
                      _showSnack('Halaman $goTo / $_pages');
                    }
                  },
          )
        ],
      ),
    );
  }

  Future<int?> _askGotoPageDialog(BuildContext ctx, int maxPages) {
    final controller = TextEditingController();
    return showDialog<int>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Pergi ke halaman'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - $maxPages'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(c, v);
            },
            child: const Text('Pergi'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternal() async {
    if (_localFilePath == null) return;
    try {
      final uri = Uri.file(_localFilePath!);
      if (!await launchUrl(uri)) {
        _showSnack('Gagal membuka file di aplikasi lain.');
      }
    } catch (_) {
      _showSnack('Gagal membuka file eksternal.');
    }
  }
}