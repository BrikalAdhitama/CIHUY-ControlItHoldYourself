import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/chat_service.dart';
import '../services/chat_log_service.dart';
import '../services/chat_storage.dart';
import 'chat_history_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? userId;
  final String? threadId;

  const ChatScreen({super.key, this.userId, this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
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
    if (widget.userId == null) return;

    try {
      await _chatStorage.openBoxesForUser(widget.userId!);
      _storageReady = true;
      _effectiveThreadId = widget.threadId ?? 'thread_default';

      if (widget.threadId != null) {
        final msgs =
            _chatStorage.loadMessages(widget.userId!, widget.threadId!);
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

  void _addMessage(String text, bool isUser, [DateTime? createdAt]) {
    final ts = createdAt ?? DateTime.now();

    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'createdAt': ts,
      });
    });

    try {
      ChatLogService.saveMessage(isUser: isUser, text: text);
    } catch (_) {}

    if (_storageReady && widget.userId != null) {
      final threadId = _effectiveThreadId ??
          'thread_${DateTime.now().millisecondsSinceEpoch}';
      _effectiveThreadId = threadId;

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

    _addMessage(userText, true);
    setState(() => _isLoading = true);

    try {
      final reply = await ChatService.sendMessage(userText);

      if (!mounted) return;
      _addMessage(reply, false);
    } catch (_) {
      if (mounted) {
        _addMessage(
          'CiHuy lagi susah dihubungi. Coba sebentar lagi ya.',
          false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime dt) {
    final t = dt.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // ================= PERBAIKAN APP BAR =================
      appBar: AppBar(
        // Menggunakan warna background scaffold agar menyatu
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0, // Hilangkan bayangan
        scrolledUnderElevation: 0, // Hilangkan efek saat discroll
        title: const Text('Teman Curhat CiHuy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
              );
            },
          ),
        ],
      ),
      // =====================================================
      body: Column(
        children: [
          // ================= CHAT LIST =================
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return _buildBubble(
                  context,
                  m['text'],
                  m['isUser'],
                  m['createdAt'],
                );
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CiHuy sedang mengetik...',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey[400] : Colors.grey,
                  ),
                ),
              ),
            ),

          // ================= INPUT CHAT =================
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,

                      // 🔥 FIX: TEXT PANJANG AUTO NUMPuk
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,

                      decoration: InputDecoration(
                        hintText: 'Ceritakan masalahmu...',
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2F4842)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00796B),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
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

  // ================= CHAT BUBBLE =================
  Widget _buildBubble(
    BuildContext context,
    String text,
    bool isUser,
    DateTime createdAt,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const userBubble = Color(0xFF00796B); // CIHUY GREEN
    const botBubbleDark = Color(0xFF263833);
    // ================= PERBAIKAN WARNA BUBBLE =================
    // Ganti jadi putih biar kontras dengan background
    const botBubbleLight = Colors.white;
    // ==========================================================

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? userBubble
              : (isDark ? botBubbleDark : botBubbleLight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isUser || isDark
              ? null
              : [
                  // Tambah sedikit bayangan halus untuk bubble putih
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isUser
                ? Text(
                    text,
                    softWrap: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  )
                : MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}