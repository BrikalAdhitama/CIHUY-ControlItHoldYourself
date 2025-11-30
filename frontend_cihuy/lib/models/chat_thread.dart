// lib/models/chat_thread.dart
class ChatThread {
  final String id;
  final String title;
  final DateTime updatedAt;
  final String lastMessage;

  ChatThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.lastMessage,
  });

  factory ChatThread.create(String id, {String? title, String? lastMessage}) {
    return ChatThread(
      id: id,
      title: title ?? 'Percakapan',
      updatedAt: DateTime.now(),
      lastMessage: lastMessage ?? '',
    );
  }
}