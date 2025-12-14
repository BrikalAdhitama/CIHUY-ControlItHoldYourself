// lib/models/hive_adapters.dart
import 'package:hive/hive.dart';

import 'chat_message.dart';
import 'chat_thread.dart';

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0;

  @override
  ChatMessage read(BinaryReader reader) {
    final map = <int, dynamic>{};
    final fieldCount = reader.readByte();
    for (int i = 0; i < fieldCount; i++) {
      final key = reader.readByte();
      final value = reader.read();
      map[key] = value;
    }

    final id = map[0] as String? ?? '';
    final threadId = map[1] as String? ?? '';
    final role = map[2] as String? ?? 'user';
    final text = map[3] as String? ?? '';

    DateTime createdAt;
    final rawCreated = map[4];
    if (rawCreated is DateTime) {
      createdAt = rawCreated;
    } else if (rawCreated is String) {
      createdAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      createdAt = DateTime.now();
    }

    final sentToServer = map[5] is bool ? map[5] as bool : false;

    return ChatMessage(
      id: id,
      threadId: threadId,
      role: role,
      text: text,
      createdAt: createdAt,
      sentToServer: sentToServer,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer.writeByte(6);

    writer.writeByte(0);
    writer.write(obj.id);

    writer.writeByte(1);
    writer.write(obj.threadId);

    writer.writeByte(2);
    writer.write(obj.role);

    writer.writeByte(3);
    writer.write(obj.text);

    // store DateTime as ISO string for portability
    writer.writeByte(4);
    writer.write(obj.createdAt.toIso8601String());

    writer.writeByte(5);
    writer.write(obj.sentToServer);
  }
}

class ChatThreadAdapter extends TypeAdapter<ChatThread> {
  @override
  final int typeId = 1;

  @override
  ChatThread read(BinaryReader reader) {
    final map = <int, dynamic>{};
    final fieldCount = reader.readByte();
    for (int i = 0; i < fieldCount; i++) {
      final key = reader.readByte();
      final value = reader.read();
      map[key] = value;
    }

    final id = map[0] as String? ?? '';
    final title = map[1] as String? ?? '';

    DateTime updatedAt;
    final rawUpdated = map[2];
    if (rawUpdated is DateTime) {
      updatedAt = rawUpdated;
    } else if (rawUpdated is String) {
      updatedAt = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    } else if (rawUpdated is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(rawUpdated);
    } else {
      updatedAt = DateTime.now();
    }

    final lastMessage = map[3] as String? ?? '';

    return ChatThread(
      id: id,
      title: title,
      updatedAt: updatedAt,
      lastMessage: lastMessage,
    );
  }

  @override
  void write(BinaryWriter writer, ChatThread obj) {
    writer.writeByte(4);

    writer.writeByte(0);
    writer.write(obj.id);

    writer.writeByte(1);
    writer.write(obj.title);

    writer.writeByte(2);
    writer.write(obj.updatedAt.toIso8601String());

    writer.writeByte(3);
    writer.write(obj.lastMessage);
  }
}

/// 🔧 Dipanggil dari main.dart
void registerHiveAdapters() {
  // Biar nggak crash kalau sampai ke-registrasi dua kali
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ChatMessageAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ChatThreadAdapter());
  }
}