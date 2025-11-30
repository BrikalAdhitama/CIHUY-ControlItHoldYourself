// lib/models/chat_message.dart
class ChatMessage {
  final String id;
  final String threadId;
  final String role; // 'user' | 'assistant' | 'system'
  final String text;
  final DateTime createdAt;
  final bool sentToServer;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.text,
    required this.createdAt,
    this.sentToServer = false,
  });

  factory ChatMessage.now({
    required String id,
    required String threadId,
    required String role,
    required String text,
  }) {
    return ChatMessage(
      id: id,
      threadId: threadId,
      role: role,
      text: text,
      createdAt: DateTime.now(),
      sentToServer: false,
    );
  }
}