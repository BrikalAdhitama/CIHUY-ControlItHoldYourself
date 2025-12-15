import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _baseUrl =
      'https://cihuy-controlitholdyourself-production.up.railway.app';

  /// Kirim pesan ke backend CIHuy
  static Future<String> sendMessage(String message) async {
    try {
      final uri = Uri.parse('$_baseUrl/chat');

      final body = jsonEncode({
        'message': message,
      });

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        final success = data['success'] as bool? ?? true;
        if (!success) {
          return data['reply'] ??
              'CIHuy lagi error, coba lagi nanti ya.';
        }

        return data['reply'] ??
            'CIHuy lagi bengong, coba ulangi pertanyaannya ya.';
      } else {
        return 'CIHuy lagi susah dihubungi (HTTP ${res.statusCode}). Coba beberapa saat lagi.';
      }
    } catch (e) {
      return 'Gagal terhubung ke CiHuy. Cek koneksi internetmu dulu ya.';
    }
  }
}
