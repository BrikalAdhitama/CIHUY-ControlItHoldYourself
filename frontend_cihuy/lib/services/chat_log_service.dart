// lib/services/chat_log_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChatLogService {
  static const _kKey = 'cihuy_chat_messages';
  static final _uuid = Uuid();

  /// Save a single message (append to local list)
  /// isUser: true => user message, false => bot message
  static Future<void> saveMessage({required bool isUser, required String text}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      List<Map<String, dynamic>> list = [];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded.map((e) => Map<String, dynamic>.from(e)));
        }
      }

      final item = {
        'id': _uuid.v4(),
        'text': text,
        'isUser': isUser,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };

      list.add(item);
      await prefs.setString(_kKey, jsonEncode(list));
    } catch (e) {
      // silent fail — we don't want to break the chat UI if logging fails
      // You can print(e) during development
      // print('[ChatLogService.saveMessage] $e');
    }
  }

  /// Load all messages (chronological)
  static Future<List<Map<String, dynamic>>> loadAllMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final list = List<Map<String, dynamic>>.from(decoded.map((e) => Map<String, dynamic>.from(e)));
      // convert createdAt to DateTime objects if needed by caller
      list.sort((a, b) {
        final ta = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
      return list;
    } catch (e) {
      // print('[ChatLogService.loadAllMessages] $e');
      return [];
    }
  }

  /// Clear all saved messages (call on logout if you want)
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
    } catch (_) {}
  }

  /// Simple grouping by date (YYYY-MM-DD) for conversation summary display
  /// returns map date => { count, lastMessage, lastAt }
  static Future<List<Map<String, dynamic>>> getDailySummaries() async {
    final msgs = await loadAllMessages();
    final Map<String, Map<String, dynamic>> groups = {};
    for (final m in msgs) {
      final created = DateTime.tryParse(m['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
      final dateKey = '${created.year.toString().padLeft(4, '0')}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
      final text = m['text'] as String? ?? '';
      if (!groups.containsKey(dateKey)) {
        groups[dateKey] = {
          'date': dateKey,
          'count': 1,
          'lastMessage': text,
          'lastAt': created.toIso8601String(),
        };
      } else {
        groups[dateKey]!['count'] = (groups[dateKey]!['count'] as int) + 1;
        // update lastMessage if this one is newer
        final prev = DateTime.tryParse(groups[dateKey]!['lastAt'] as String) ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (created.isAfter(prev)) {
          groups[dateKey]!['lastMessage'] = text;
          groups[dateKey]!['lastAt'] = created.toIso8601String();
        }
      }
    }

    final list = groups.values.toList();
    list.sort((a, b) {
      final ta = DateTime.tryParse(a['lastAt'] as String) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = DateTime.tryParse(b['lastAt'] as String) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    return list;
  }
}