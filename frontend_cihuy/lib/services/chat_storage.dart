// lib/services/chat_storage.dart
import 'package:flutter/foundation.dart'; // <- ADDED: ValueListenable type
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';

class ChatStorage {
  static final ChatStorage _i = ChatStorage._();
  factory ChatStorage() => _i;
  ChatStorage._();

  final _uuid = const Uuid();

  String _msgBoxName(String userId) => 'chat_messages_$userId';
  String _threadBoxName(String userId) => 'chat_threads_$userId';

  Future<void> openBoxesForUser(String userId) async {
    if (!Hive.isBoxOpen(_msgBoxName(userId))) {
      await Hive.openBox<ChatMessage>(_msgBoxName(userId));
    }
    if (!Hive.isBoxOpen(_threadBoxName(userId))) {
      await Hive.openBox<ChatThread>(_threadBoxName(userId));
    }
  }

  Future<void> _ensureBoxesOpen(String userId) async {
    if (!Hive.isBoxOpen(_msgBoxName(userId)) || !Hive.isBoxOpen(_threadBoxName(userId))) {
      await openBoxesForUser(userId);
    }
  }

  Box<ChatMessage> _msgBox(String userId) => Hive.box<ChatMessage>(_msgBoxName(userId));
  Box<ChatThread> _threadBox(String userId) => Hive.box<ChatThread>(_threadBoxName(userId));

  Future<ChatThread> createThread(String userId, {String? title, String? firstMessage}) async {
    await _ensureBoxesOpen(userId);

    final id = _uuid.v4();
    final t = ChatThread(
      id: id,
      title: title ?? 'Percakapan baru',
      updatedAt: DateTime.now(),
      lastMessage: firstMessage ?? '',
    );
    await _threadBox(userId).put(id, t);
    return t;
  }

  Future<ChatMessage> addMessage(String userId, {required String threadId, required String role, required String text, bool sentToServer = false}) async {
    await _ensureBoxesOpen(userId);

    final id = _uuid.v4();
    final msg = ChatMessage(id: id, threadId: threadId, role: role, text: text, createdAt: DateTime.now(), sentToServer: sentToServer);
    await _msgBox(userId).put(id, msg);

    final threadBox = _threadBox(userId);
    final thread = threadBox.get(threadId);

    final now = DateTime.now();
    if (thread != null) {
      final updatedThread = ChatThread(
        id: thread.id,
        title: thread.title,
        updatedAt: now,
        lastMessage: text,
      );
      await threadBox.put(threadId, updatedThread);
    } else {
      final t = ChatThread(
        id: threadId,
        title: text.length > 30 ? text.substring(0, 30) : text,
        updatedAt: now,
        lastMessage: text,
      );
      await threadBox.put(threadId, t);
    }

    return msg;
  }

  List<ChatThread> loadThreads(String userId) {
    final box = _threadBox(userId);
    final list = box.values.toList().cast<ChatThread>();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<ChatMessage> loadMessages(String userId, String threadId) {
    final box = _msgBox(userId);
    final msgs = box.values.where((m) => m.threadId == threadId).toList().cast<ChatMessage>();
    msgs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return msgs;
  }

  // return a ValueListenable so UI code can listen() directly
  ValueListenable<Box<ChatThread>> threadsListenable(String userId) =>
      Hive.box<ChatThread>(_threadBoxName(userId)).listenable();

  ValueListenable<Box<ChatMessage>> messagesListenable(String userId) =>
      Hive.box<ChatMessage>(_msgBoxName(userId)).listenable();

  Future<void> deleteThread(String userId, String threadId) async {
    await _ensureBoxesOpen(userId);
    final msgBox = _msgBox(userId);
    final threadBox = _threadBox(userId);

    final msgs = msgBox.values.where((m) => m.threadId == threadId).toList();
    final keys = msgs.map((m) => m.id).toList();

    if (keys.isNotEmpty) {
      await msgBox.deleteAll(keys);
    }
    await threadBox.delete(threadId);
  }

  Future<void> clearAllForUser(String userId) async {
    await _ensureBoxesOpen(userId);
    await _msgBox(userId).clear();
    await _threadBox(userId).clear();
  }
}