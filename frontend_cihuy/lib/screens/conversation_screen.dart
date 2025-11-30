// lib/screens/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../services/chat_storage.dart';
import '../models/chat_thread.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final String userId;
  const ConversationsScreen({super.key, required this.userId});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _storage = ChatStorage();
  bool _boxesOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _storage.openBoxesForUser(widget.userId);
      if (!mounted) return;
      setState(() => _boxesOpened = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Chat')),
      body: _boxesOpened
          ? ValueListenableBuilder<Box<ChatThread>>(
              valueListenable: _storage.threadsListenable(widget.userId),
              builder: (context, box, _) {
                final threads = _storage.loadThreads(widget.userId);
                if (threads.isEmpty) {
                  return const Center(child: Text('Belum ada percakapan'));
                }
                return ListView.builder(
                  itemCount: threads.length,
                  itemBuilder: (ctx, i) {
                    final ChatThread t = threads[i];
                    final title = t.title.isNotEmpty ? t.title : 'Percakapan';
                    final subtitle = t.lastMessage.isNotEmpty ? t.lastMessage : '—';
                    return ListTile(
                      key: ValueKey(t.id),
                      leading: const CircleAvatar(
                        backgroundImage: AssetImage('assets/icon-app.png'),
                      ),
                      title: Text(title),
                      subtitle: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(_prettyTime(t.updatedAt)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              userId: widget.userId,
                              threadId: t.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final thread = await _storage.createThread(
            widget.userId,
            title: 'Percakapan baru',
          );
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(userId: widget.userId, threadId: thread.id),
            ),
          );
        },
      ),
    );
  }

  String _prettyTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }
}