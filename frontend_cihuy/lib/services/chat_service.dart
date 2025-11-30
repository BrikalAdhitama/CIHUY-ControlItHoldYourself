import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Ganti ke URL ngrok lu sekarang
  static const String _baseUrl = 'https://unjustly-snuffier-clora.ngrok-free.dev';

  /// Kirim pesan ke backend CIHuy
  /// [message] = pesan user sekarang
  /// [history] = list riwayat chat: [{'sender': 'user'/'bot', 'text': '...'}, ...]
  static Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/chat');

      final body = jsonEncode({
        'message': message,
        'history': history,
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // Debug log
      // print('CIHuy status: ${res.statusCode}, body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? true;
        if (!success) {
          return data['error']?.toString() ??
              'CIHuy lagi error, coba lagi nanti ya.';
        }
        return (data['reply'] as String?) ??
            'CIHuy lagi bengong, coba ulangi pertanyaannya ya.';
      } else {
        return 'CIHuy lagi susah dihubungi (HTTP ${res.statusCode}). Coba beberapa saat lagi.';
      }
    } catch (e) {
      // print('ChatService error: $e');
      return 'Gagal terhubung ke CiHuy. Cek koneksi internetmu dulu ya.';
    }
  }
}
