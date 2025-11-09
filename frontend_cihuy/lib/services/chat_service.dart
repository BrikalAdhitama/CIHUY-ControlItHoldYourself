import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  // PASTIKAN URL INI SAMA DENGAN YANG DI auth_service.dart
  static const String _baseUrl = 'https://unjustly-snuffier-clora.ngrok-free.dev';

  static Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? 'Maaf, saya tidak mengerti.';
      } else {
        return 'Gagal terhubung ke CiHuy (Error ${response.statusCode})';
      }
    } catch (e) {
      return 'Error koneksi: $e';
    }
  }
}