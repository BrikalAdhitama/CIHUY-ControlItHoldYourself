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

class _ChatScreenState extends State<ChatScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  final ChatStorage _chatStorage = ChatStorage();
  bool _storageReady = false;
  String? _effectiveThreadId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initStorageIfNeeded();
  }

  Future<void> _initStorageIfNeeded() async {
    if (widget.userId == null) return;

    try {
      await _chatStorage.openBoxesForUser(widget.userId!);
      _storageReady = true;
      
      _effectiveThreadId = widget.threadId ?? 'main_session_v1';

      if (_effectiveThreadId != null) {
        final msgs = _chatStorage.loadMessages(widget.userId!, _effectiveThreadId!);
        
        if (msgs.isNotEmpty) {
          for (final m in msgs) {
            _messages.add({
              'text': m.text,
              'isUser': m.role == 'user',
              'createdAt': m.createdAt,
            });
          }
        } 
      }
    } catch (_) {
      _storageReady = false;
    }

    if (mounted) setState(() {});
  }

  void _addMessage(String text, bool isUser, {DateTime? createdAt, bool saveToDb = true}) {
    final ts = createdAt ?? DateTime.now();

    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'createdAt': ts,
      });
    });

    try {
      if (saveToDb) ChatLogService.saveMessage(isUser: isUser, text: text);
    } catch (_) {}

    if (_storageReady && widget.userId != null && saveToDb) {
      final threadId = _effectiveThreadId ?? 'main_session_v1';
      
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
    final textToSend = _controller.text.trim();

    if (textToSend.isEmpty || _isLoading) return;

    _controller.clear();

    _addMessage(textToSend, true); 
    setState(() => _isLoading = true);

    try {
      final reply = await ChatService.sendMessage(textToSend);

      if (!mounted) return;
      _addMessage(reply, false); 
    } catch (_) {
      if (mounted) {
        _addMessage(
          'Cia lagi susah dihubungi. Coba sebentar lagi ya.',
          false,
          saveToDb: false 
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
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Curhat bersama Cia'),
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
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
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
                child: Row(
                  children: [
                    // Avatar kecil saat loading (typing indicator)
                    const CircleAvatar(
                      radius: 12,
                      backgroundImage: AssetImage('assets/icon-cihuy-ai.jpg'),
                      backgroundColor: Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cia sedang mengetik...',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                    backgroundColor: const Color(0xFF00A884), // Hijau WA
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : () => _sendMessage(),
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

  // --- WIDGET TAMPILAN KOSONG (CLEAN VERSION) ---
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Karakter Besar (Avatar)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A884).withOpacity(0.15), 
              ),
              child: const CircleAvatar(
                radius: 70, // Ukuran Besar
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/icon-cihuy-ai.jpg'),
              ),
            ),
            const SizedBox(height: 24),
            
            // 2. Sapaan Ramah
            Text(
              "Halo, Sahabat CiHuy! 👋",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Aku siap dengerin cerita kamu hari ini.\nYuk, mulai ngobrol santai aja...",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUBBLE CHAT DENGAN AVATAR ---
  Widget _buildBubble(
    BuildContext context,
    String text,
    bool isUser,
    DateTime createdAt,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const userBubbleColor = Color(0xFF00A884); 
    final botBubbleColor = isDark ? const Color(0xFF303030) : Colors.white;

    final textColor = isUser ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final timeColor = isUser ? Colors.white70 : (isDark ? Colors.grey[400] : Colors.grey[600]);

    final bubbleContainer = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.70,
      ),
      decoration: BoxDecoration(
        color: isUser ? userBubbleColor : botBubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
        ),
        boxShadow: (!isUser && !isDark)
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isUser
              ? Text(
                  text,
                  style: TextStyle(color: textColor, fontSize: 15),
                )
              : MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 15, color: textColor),
                    strong: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _formatTime(createdAt),
              style: TextStyle(fontSize: 10, color: timeColor),
            ),
          ),
        ],
      ),
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubbleContainer,
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage('assets/icon-cihuy-ai.jpg'),
            ),
            const SizedBox(width: 8),
            Flexible( 
              child: bubbleContainer,
            ),
          ],
        ),
      );
    }
  }
}