import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'education_detail_screen.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];

  bool _loading = true;
  bool _refreshing = false;
  String _query = '';
  Set<String> _bookmarks = {};

  static const _cacheKey = 'cihuy_edu_cache_v2';
  static const _bookmarkKey = 'cihuy_edu_bookmarks_v1';

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadCachedThenRemote();
  }

  // ================= BOOKMARK =================
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarkKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _bookmarks = (jsonDecode(raw) as List)
            .map((e) => e.toString())
            .toSet();
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookmarkKey, jsonEncode(_bookmarks.toList()));
  }

  void _toggleBookmark(String id) {
    _bookmarks.contains(id)
        ? _bookmarks.remove(id)
        : _bookmarks.add(id);
    _saveBookmarks();
    setState(() {});
  }

  // ================= CACHE + FETCH =================
  Future<void> _loadCachedThenRemote() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);

    if (raw != null) {
      try {
        _items = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _applyFilter();
      } catch (_) {}
    }

    await _fetchFromServer();
    setState(() => _loading = false);
  }

  Future<void> _fetchFromServer() async {
    try {
      final videoRes = await _supabase
          .from('educations_video')
          .select('*')
          .order('updated_at', ascending: false);

      final pdfRes = await _supabase
          .from('educations_pdf')
          .select('*')
          .order('updated_at', ascending: false);

      final mdRes = await _supabase
          .from('educations_md')
          .select('*')
          .order('updated_at', ascending: false);

      final merged = <Map<String, dynamic>>[
        ...(videoRes as List).map((e) => {...e, 'type': 'video'}),
        ...(pdfRes as List).map((e) => {...e, 'type': 'pdf'}),
        ...(mdRes as List).map((e) => {...e, 'type': 'md'}),
      ];

      merged.sort((a, b) =>
          b['updated_at'].toString().compareTo(a['updated_at'].toString()));

      _items = merged;
      _applyFilter();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_items));
    } catch (_) {}
    setState(() {});
  }

  Future<void> _pullToRefresh() async {
    setState(() => _refreshing = true);
    await _fetchFromServer();
    setState(() => _refreshing = false);
  }

  // ================= FILTER =================
  void _applyFilter() {
    final q = _query.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_items)
        : _items.where((m) {
            return (m['title'] ?? '').toString().toLowerCase().contains(q) ||
                (m['summary'] ?? '').toString().toLowerCase().contains(q) ||
                (m['content_markdown'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(q);
          }).toList();
    setState(() {});
  }

  // ================= HELPER WIDGET: NOT FOUND =================
  // [NEW] Widget tampilan saat data kosong/tidak ketemu
  Widget _buildNotFoundState(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Agar tetap bisa di-refresh
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6, // Biar posisi di tengah
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Yah, artikel tidak ditemukan...',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba cari kata kunci lain ya!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primary = Color(0xFF00796B);
    
    // Warna Background Hijau Muda CIHUY (sesuai Home)
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFE0F2F1);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Edukasi Rokok & Vape',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bookmark,
              color: _bookmarks.isNotEmpty ? primary : textColor,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _BookmarksScreen(
                    bookmarkedIds: _bookmarks,
                    allItems: _items,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari topik (misal: batuk, nikotin)...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: primary),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: primary, width: 1.5),
                ),
              ),
              style: TextStyle(color: textColor),
              onChanged: (v) {
                _query = v;
                _applyFilter();
              },
            ),
          ),

          // LIST
          Expanded(
            child: RefreshIndicator(
              color: primary,
              onRefresh: _pullToRefresh,
              child: _loading && _filtered.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (_, __) => const _EduSkeleton(),
                    )
                  // [UPDATE] Logika untuk menampilkan Not Found jika kosong
                  : _filtered.isEmpty 
                      ? _buildNotFoundState(isDark) // Tampilkan widget Not Found
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item = _filtered[i];
                            final id = item['id'].toString();
                            final type = item['type'];

                            final badgeColor = type == 'video'
                                ? Colors.blue
                                : type == 'pdf'
                                    ? Colors.red
                                    : primary;

                            return Card(
                              elevation: 0,
                              color: cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.grey.withOpacity(0.1), 
                                  width: 1
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EducationDetailScreen(item: item),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ICON KIRI
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          type == 'video'
                                              ? Icons.play_arrow_rounded
                                              : type == 'pdf'
                                                  ? Icons.picture_as_pdf_rounded
                                                  : Icons.menu_book_rounded,
                                          color: badgeColor,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // TEXT TENGAH
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['title'] ?? '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (item['summary'] ?? '').toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // BOOKMARK KANAN
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          _bookmarks.contains(id)
                                              ? Icons.bookmark
                                              : Icons.bookmark_border_rounded,
                                          color: primary,
                                          size: 22,
                                        ),
                                        onPressed: () => _toggleBookmark(id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= SKELETON =================
class _EduSkeleton extends StatelessWidget {
  const _EduSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ================= BOOKMARK =================
class _BookmarksScreen extends StatelessWidget {
  final Set<String> bookmarkedIds;
  final List<Map<String, dynamic>> allItems;

  const _BookmarksScreen({
    required this.bookmarkedIds,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context) {
    final items = allItems
        .where((e) => bookmarkedIds.contains(e['id'].toString()))
        .toList();
        
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmark Edukasi', style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Belum ada bookmark', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    title: Text(it['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      (it['summary'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EducationDetailScreen(item: it),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}