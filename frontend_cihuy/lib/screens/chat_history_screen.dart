// lib/screens/chat_history_screen.dart
import 'package:flutter/material.dart';
import '../services/chat_log_service.dart';

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
    // load all messages and filter by date
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

    // refresh after returning in case user cleared
    await _loadSummaries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      leading: CircleAvatar(child: const Icon(Icons.history)),
                      title: Text(prettyDate),
                      subtitle: Text(last, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('$count'),
                      onTap: () => _openDetail(dateKey),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.delete_forever),
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

class ChatHistoryDetailScreen extends StatelessWidget {
  final String dateKey;
  final List<Map<String, dynamic>> messages;
  const ChatHistoryDetailScreen({super.key, required this.dateKey, required this.messages});

  @override
  Widget build(BuildContext context) {
    messages.sort((a, b) {
      final ta = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });

    return Scaffold(
      appBar: AppBar(title: Text('Percakapan: ${_prettyDate(dateKey)}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (ctx, i) {
          final m = messages[i];
          final isUser = (m['isUser'] == true);
          final text = m['text'] as String? ?? '';
          final created = DateTime.tryParse(m['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(text, style: TextStyle(color: isUser ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))),
                  const SizedBox(height: 6),
                  Text(
                    '${created.hour.toString().padLeft(2,'0')}:${created.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
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