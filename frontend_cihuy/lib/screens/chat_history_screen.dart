// lib/screens/chat_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Wajib ada di pubspec.yaml
import '../services/chat_log_service.dart';

// ---------------------------------------------------------------------------
// SCREEN 1: LIST RIWAYAT (DAFTAR TANGGAL)
// ---------------------------------------------------------------------------

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _summaries = [];

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    setState(() => _loading = true);
    final s = await ChatLogService.getDailySummaries();
    if (!mounted) return;
    setState(() {
      _summaries = s;
      _loading = false;
    });
  }

  Future<void> _openDetail(String dateKey) async {
    // Load semua pesan lalu filter berdasarkan tanggal
    final all = await ChatLogService.loadAllMessages();
    final items = all.where((m) {
      final created = DateTime.tryParse(m['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
      final key = '${created.year.toString().padLeft(4, '0')}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      return key == dateKey;
    }).toList();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatHistoryDetailScreen(dateKey: dateKey, messages: items),
      ),
    );

    // Refresh setelah kembali (jaga-jaga user menghapus history)
    await _loadSummaries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Percakapan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? const Center(child: Text('Belum ada riwayat percakapan'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _summaries.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final s = _summaries[i];
                    final dateKey = s['date'] as String;
                    final count = s['count'] as int;
                    final last = s['lastMessage'] as String;
                    final prettyDate = _prettyDate(dateKey);
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.history)),
                      title: Text(prettyDate),
                      subtitle: Text(last, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('$count'),
                      onTap: () => _openDetail(dateKey),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete_forever, color: Colors.white),
        tooltip: 'Hapus semua riwayat',
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Hapus semua riwayat?'),
              content: const Text('Semua percakapan yang tersimpan akan dihapus permanen.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (ok == true) {
            await ChatLogService.clearAll();
            await _loadSummaries();
          }
        },
      ),
    );
  }

  String _prettyDate(String ymd) {
    try {
      final parts = ymd.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final dt = DateTime(y, m, d);
      return '${dt.day}-${dt.month}-${dt.year}';
    } catch (_) {
      return ymd;
    }
  }
}

// ---------------------------------------------------------------------------
// SCREEN 2: DETAIL CHAT (BUBBLE CHAT)
// ---------------------------------------------------------------------------

class ChatHistoryDetailScreen extends StatelessWidget {
  final String dateKey;
  final List<Map<String, dynamic>> messages;
  const ChatHistoryDetailScreen({super.key, required this.dateKey, required this.messages});

  @override
  Widget build(BuildContext context) {
    // 1. Sorting pesan agar urut waktu
    messages.sort((a, b) {
      final ta = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Percakapan: ${_prettyDate(dateKey)}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (ctx, i) {
          final m = messages[i];
          
          // 2. Cek Pengirim (Support boolean true atau integer 1)
          final isUser = (m['isUser'] == true || m['isUser'] == 1);
          
          final text = m['text'] as String? ?? '';
          final created = DateTime.tryParse(m['createdAt'] ?? '')?.toLocal() ?? DateTime.now();

          // 3. LOGIC WARNA BUBBLE (FIXED: User Pakai HIJAU WA)
          final bubbleColor = isUser
              ? const Color(0xFF00A884) // <--- INI HIJAU KHAS WHATSAPP
              : isDarkMode
                  ? const Color(0xFF303030) // AI Dark Mode (Abu Gelap)
                  : Colors.grey[200];       // AI Light Mode (Abu Terang)

          // 4. LOGIC WARNA TEXT
          final textColor = isUser 
              ? Colors.white 
              : (isDarkMode ? Colors.white : Colors.black);

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85, // Max 85% lebar layar
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  // Buntat di sisi pengirim, tumpul di sisi lawan
                  bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(0),
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 5. RENDER MARKDOWN (Agar bintang ** hilang dan jadi Bold)
                  MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: textColor, fontSize: 16),
                      strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      blockSpacing: 8.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _prettyDate(String ymd) {
    try {
      final parts = ymd.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final dt = DateTime(y, m, d);
      return '${dt.day}-${dt.month}-${dt.year}';
    } catch (_) {
      return ymd;
    }
  }
}