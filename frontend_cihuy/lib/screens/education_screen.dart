// lib/screens/education_screen.dart
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

  /// Kombinasi dari video + pdf + md
  /// { id, title, summary, content_markdown?, updated_at,
  ///   type: 'video'|'pdf'|'md', video_url?/pdf_url?/md_url? }
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filtered = [];

  bool _loading = true;
  bool _refreshing = false;
  String _query = '';
  Set<String> _bookmarks = {};

  static const _cacheKey = 'cihuy_edu_cache_v2';
  static const _bookmarkKey = 'cihuy_edu_bookmarks_v1';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadCachedThenRemote();
  }

  // --------------------------------
  // BOOKMARKS
  // --------------------------------
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarkKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _bookmarks = decoded.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookmarkKey, jsonEncode(_bookmarks.toList()));
  }

  // --------------------------------
  // CACHE + FETCH
  // --------------------------------
  Future<void> _loadCachedThenRemote() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);

    // pakai cache dulu kalau ada
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _applyFilter();
      } catch (_) {}
    }

    // lalu ambil data terbaru dari server
    await _fetchFromServer();
    setState(() => _loading = false);
  }

  Future<void> _fetchFromServer() async {
    try {
      // 1) VIDEO dari tabel educations_video
      final videoRes = await _supabase
          .from('educations_video')
          .select('*')
          .order('updated_at', ascending: false);

      final List<Map<String, dynamic>> videos =
          (videoRes as List).map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e);
        map['type'] = 'video';
        return map;
      }).toList();

      // 2) PDF dari tabel educations_pdf
      final pdfRes = await _supabase
          .from('educations_pdf')
          .select('*')
          .order('updated_at', ascending: false);

      final List<Map<String, dynamic>> pdfs =
          (pdfRes as List).map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e);
        map['type'] = 'pdf';
        return map;
      }).toList();

      // 3) MD ARTICLE dari tabel educations_md
      final mdRes = await _supabase
          .from('educations_md')
          .select('*')
          .order('updated_at', ascending: false);

      final List<Map<String, dynamic>> mds =
          (mdRes as List).map<Map<String, dynamic>>((e) {
        final map = Map<String, dynamic>.from(e);
        map['type'] = 'md'; // <- penanda artikel MD
        return map;
      }).toList();

      // 4) gabung
      final merged = <Map<String, dynamic>>[
        ...videos,
        ...pdfs,
        ...mds,
      ];

      // sort by updated_at desc
      merged.sort((a, b) {
        final sa = (a['updated_at'] ?? '').toString();
        final sb = (b['updated_at'] ?? '').toString();
        try {
          final da = DateTime.parse(sa);
          final db = DateTime.parse(sb);
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });

      _items = merged;
      _applyFilter();

      // simpan cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_items));
    } catch (e) {
      // sementara pakai cache lama aja kalau error
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _pullToRefresh() async {
    setState(() => _refreshing = true);
    await _fetchFromServer();
    setState(() => _refreshing = false);
  }

  // --------------------------------
  // FILTER / SEARCH
  // --------------------------------
  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_items);
    } else {
      _filtered = _items.where((m) {
        final t = (m['title'] ?? '').toString().toLowerCase();
        final s = (m['summary'] ?? '').toString().toLowerCase();
        final c = (m['content_markdown'] ?? '').toString().toLowerCase();
        return t.contains(q) || s.contains(q) || c.contains(q);
      }).toList();
    }
    if (mounted) setState(() {});
  }

  // --------------------------------
  // BOOKMARK TOGGLE
  // --------------------------------
  void _toggleBookmark(String id) {
    if (_bookmarks.contains(id)) {
      _bookmarks.remove(id);
    } else {
      _bookmarks.add(id);
    }
    _saveBookmarks();
    setState(() {});
  }

  // --------------------------------
  // ICON & COLOR
  // --------------------------------
  IconData _iconForItem(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString();
    switch (type) {
      case 'video':
        return Icons.play_circle_fill;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'md':
        return Icons.menu_book_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Color? _iconColorForItem(BuildContext context, Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString();
    switch (type) {
      case 'video':
        return Theme.of(context).colorScheme.primary;
      case 'pdf':
        return Colors.redAccent;
      case 'md':
        return Colors.teal;
      default:
        return null;
    }
  }

  static String _prettyDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edukasi Rokok & Vape'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bookmark,
              color: _bookmarks.isEmpty
                  ? (isDark ? Colors.white70 : null)
                  : theme.colorScheme.secondary,
            ),
            tooltip: 'Lihat Bookmark',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _BookmarksScreen(
                    bookmarkedIds: _bookmarks.toSet(),
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
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari topik (misal: batuk, nikotin, berhenti)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query = '';
                          _applyFilter();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (v) {
                _query = v;
                _applyFilter();
              },
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _pullToRefresh,
              child: _loading && _filtered.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: 6,
                      itemBuilder: (_, __) => const _EduSkeleton(),
                    )
                  : _filtered.isEmpty
                      ? ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 60),
                            Center(
                              child: Text(
                                'Belum ada konten edukasi.\nCoba tarik ke bawah untuk refresh.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = _filtered[idx];
                            final id = item['id'].toString();
                            final title =
                                item['title']?.toString() ?? 'Tanpa judul';
                            final summary =
                                (item['summary'] ?? '').toString();
                            final updated =
                                item['updated_at']?.toString() ?? '';
                            final type =
                                (item['type'] ?? '').toString();

                            final iconData = _iconForItem(item);
                            final iconColor =
                                _iconColorForItem(context, item);

                            String badgeText;
                            Color badgeColor;
                            if (type == 'video') {
                              badgeText = 'Video';
                              badgeColor = Colors.blue;
                            } else if (type == 'pdf') {
                              badgeText = 'Dokumen';
                              badgeColor = Colors.red;
                            } else {
                              badgeText = 'Artikel';
                              badgeColor = Colors.teal;
                            }

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                leading: Icon(iconData,
                                    size: 32, color: iconColor),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: badgeColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (summary.isNotEmpty)
                                      Text(
                                        summary,
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    if (updated.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                top: 4.0),
                                        child: Text(
                                          _prettyDate(updated),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    _bookmarks.contains(id)
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                  ),
                                  onPressed: () =>
                                      _toggleBookmark(id),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EducationDetailScreen(
                                            item: item,
                                          ),
                                    ),
                                  );
                                },
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

// Skeleton & Bookmark screen tetap sama (boleh pakai yang punyamu tadi)

class _EduSkeleton extends StatelessWidget {
  const _EduSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius:
                  BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 12,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Container(
                  width: MediaQuery.of(context)
                          .size
                          .width *
                      0.6,
                  height: 10,
                  color: Colors.grey.shade200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarksScreen extends StatelessWidget {
  final Set<String> bookmarkedIds;
  final List<Map<String, dynamic>> allItems;

  const _BookmarksScreen({
    super.key,
    required this.bookmarkedIds,
    required this.allItems,
  });

  @override
  Widget build(BuildContext context) {
    final items = allItems
        .where((e) => bookmarkedIds.contains(e['id'].toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bookmark Edukasi')),
      body: items.isEmpty
          ? const Center(child: Text('Belum ada bookmark'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final it = items[i];
                return ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: Text(it['title'] ?? ''),
                  subtitle: Text(
                    (it['summary'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EducationDetailScreen(item: it),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
