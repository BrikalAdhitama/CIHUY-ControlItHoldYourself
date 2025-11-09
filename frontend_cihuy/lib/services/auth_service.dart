import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  // URL Ngrok Anda (pastikan ini selalu update jika Ngrok di-restart)
  static const String _baseUrl = 'https://unjustly-snuffier-clora.ngrok-free.dev';

  // --- Fungsi Login ---
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'username': data['username']
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login gagal'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak bisa terhubung ke server.\nError: $e'
      };
    }
  }

  // --- Fungsi Register ---
  static Future<Map<String, dynamic>> register(
      String email, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Registrasi berhasil'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi gagal'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Tidak bisa terhubung ke server.\nError: $e'
      };
    }
  }

  // --- Fungsi Reset Timer (Baru) ---
  static Future<bool> resetTimer(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/set_quit_date'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Fungsi Ambil Progress Timer (Akan dipakai nanti) ---
  static Future<Map<String, dynamic>> getProgress(String username) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/get_progress/$username'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false};
      }
    } catch (e) {
      return {'success': false};
    }
  }
}