// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/chat_service.dart';
import '../services/chat_log_service.dart';
import '../services/chat_storage.dart';
import 'chat_history_screen.dart';

class ChatScreen extends StatefulWidget {
  /// Optional userId untuk menyimpan ke Hive (ChatStorage)
  final String? userId;

  /// Optional threadId untuk membuka thread spesifik
  final String? threadId;

  const ChatScreen({super.key, this.userId, this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // {'text','isUser','createdAt'}
  bool _isLoading = false;

  final ChatStorage _chatStorage = ChatStorage();
  bool _storageReady = false;
  String? _effectiveThreadId;

  @override
  void initState() {
    super.initState();
    _initStorageIfNeeded();
    _addMessage(
      'Halo! Saya CiHuy, teman curhatmu untuk berhenti merokok. Apa yang kamu rasakan hari ini?',
      false,
    );
  }

  Future<void> _initStorageIfNeeded() async {
    if (widget.userId != null) {
      try {
        await _chatStorage.openBoxesForUser(widget.userId!);
        _storageReady = true;
        _effectiveThreadId = widget.threadId ?? 'thread_local_default';

        if (widget.threadId != null) {
          final msgs = _chatStorage.loadMessages(widget.userId!, widget.threadId!);
          for (final m in msgs) {
            _messages.add({
              'text': m.text,
              'isUser': m.role == 'user',
              'createdAt': m.createdAt,
            });
          }
        }
      } catch (_) {
        _storageReady = false;
      }
      if (mounted) setState(() {});
    }
  }

  /// Add message to UI + local logging/storage.
  /// createdAt optional (backwards compatible).
  void _addMessage(String text, bool isUser, [DateTime? createdAt]) {
    final DateTime ts = createdAt ?? DateTime.now();

    setState(() {
      _messages.add({'text': text, 'isUser': isUser, 'createdAt': ts});
    });

    // Persist to ChatLogService (SharedPreferences). Current API doesn't accept createdAt.
    try {
      ChatLogService.saveMessage(isUser: isUser, text: text);
    } catch (_) {
      // ignore, logging failure shouldn't break UI
    }

    // Persist to ChatStorage (Hive) if available
    if (_storageReady && widget.userId != null) {
      final threadId = _effectiveThreadId ??
          (widget.threadId ?? 'thread_local_${DateTime.now().millisecondsSinceEpoch}');
      _effectiveThreadId = threadId;

      // ChatStorage.addMessage will set createdAt internally to DateTime.now()
      _chatStorage.addMessage(
        widget.userId!,
        threadId: threadId,
        role: isUser ? 'user' : 'assistant',
        text: text,
        sentToServer: false,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;

    final userText = _controller.text.trim();
    _controller.clear();

    final now = DateTime.now();
    _addMessage(userText, true, now);

    setState(() => _isLoading = true);

    try {
      final List<Map<String, String>> historyForBackend = _messages.map((msg) {
        final isUsr = msg['isUser'] as bool? ?? false;
        final t = msg['text'] as String? ?? '';
        return {
          'sender': isUsr ? 'user' : 'bot',
          'text': t,
        };
      }).toList();

      final reply = await ChatService.sendMessage(userText, history: historyForBackend);

      if (!mounted) return;
      final replyText = reply ?? 'Maaf, CiHuy gak bisa bales sekarang.';
      _addMessage(replyText, false, DateTime.now());
    } catch (e) {
      if (mounted) {
        _addMessage('Gagal mengirim pesan: ${e.toString()}', false, DateTime.now());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final t = dt.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Teman Curhat CiHuy',
          style: TextStyle(color: theme.appBarTheme.titleTextStyle?.color ?? textColor),
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? (isDarkMode ? const Color(0xFF121212) : Colors.white),
        elevation: 1,
        iconTheme: theme.appBarTheme.iconTheme ?? IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Motivasi',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final text = msg['text'] as String? ?? '';
                final isUser = msg['isUser'] as bool? ?? false;
                final createdAt = msg['createdAt'] as DateTime? ?? DateTime.now();
                return _buildChatBubble(context, text, isUser, createdAt);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CiHuy sedang mengetik...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 14),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF121212) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Ceritakan masalahmu...',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildChatBubble(BuildContext context, String text, bool isUser, DateTime createdAt) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color userBubbleColor = theme.colorScheme.primary;
    final Color botBubbleColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100]!;
    final Color botTextColor = isDarkMode ? Colors.white : Colors.black87;

    // korte styling supaya bubble gak kegedean
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), // spacing antar bubble
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // compact padding
        constraints: BoxConstraints(
          // maks width lebih kecil biar bubble compact untuk pesan pendek
          maxWidth: MediaQuery.of(context).size.width * 0.70,
          minWidth: 0,
        ),
        decoration: BoxDecoration(
          color: isUser ? userBubbleColor : botBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // penting: biar height ngekek sesuai content
          children: [
            // pesan (user plain text, bot markdown)
            if (isUser)
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.25, // rapetin line height
                ),
              )
            else
              // MarkdownBody kadang kasih spacing ekstra, kita override style agar compact
              MarkdownBody(
                data: text,
                selectable: false,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(color: botTextColor, fontSize: 15, height: 1.25),
                  strong: TextStyle(fontWeight: FontWeight.w700, color: botTextColor),
                  em: TextStyle(fontStyle: FontStyle.italic, color: botTextColor),
                  listBullet: TextStyle(color: botTextColor, fontSize: 15),
                  // reduce heading sizes to avoid huge gaps if backend sends headings
                  h1: TextStyle(fontSize: 16, color: botTextColor),
                  h2: TextStyle(fontSize: 15, color: botTextColor),
                  blockSpacing: 4, // reduce spacing between blocks
                  listIndent: 16,
                ),
              ),

            // waktu kecil di pojok kanan bawah
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}