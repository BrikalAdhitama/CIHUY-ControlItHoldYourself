// lib/services/fcm_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

// --- CONFIG SERVER PYTHON ---
// Pastikan URL ngrok ini masih aktif/valid ya!
const String BACKEND_URL = "https://unjustly-snuffier-clora.ngrok-free.dev/save-token";
// ----------------------------

/// HANDLER BACKGROUND (FIXED)
/// Saat aplikasi tertutup/background, Android otomatis menampilkan notifikasi dari server.
/// Jadi kita TIDAK BOLEH memanggil 'showImmediate' di sini agar tidak double.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Cukup inisialisasi Firebase saja
  await Firebase.initializeApp();
  
  // Log saja untuk debugging, jangan tampilkan UI manual
  debugPrint('[FcmService] Background message received: ${message.messageId}');
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      // Set handler background yang sudah diperbaiki di atas
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      if (Platform.isIOS) {
        final settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true,
        );
        debugPrint('[FcmService] iOS permission: $settings');
      }

      // --- FOREGROUND HANDLER (Saat Aplikasi Dibuka) ---
      // Di sini kita WAJIB pakai showImmediate karena Android tidak memunculkan
      // notifikasi sistem jika aplikasi sedang dibuka di layar.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          final notif = message.notification;
          final title = notif?.title ?? 'CIHUY';
          final body = notif?.body ?? (message.data['body'] ?? '');
          
          NotificationService.showImmediate(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: title,
            body: body,
            payload: message.data.isNotEmpty ? message.data.toString() : null,
          );
          debugPrint('[FcmService] onMessage handled (Foreground): ${message.messageId}');
        } catch (e, st) {
          debugPrint('[FcmService] onMessage error: $e\n$st');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FcmService] onMessageOpenedApp: ${message.data}');
      });

      // --- BAGIAN UTAMA: AMBIL TOKEN & KIRIM KE PYTHON ---
      final token = await _messaging.getToken();
      
      if (token != null) {
        // Kirim token ke backend
        await _sendTokenToBackend(token);
      }
      // ----------------------------------------------------

    } catch (e, st) {
      debugPrint('[FcmService] init error: $e\n$st');
    }
  }

  // --- FUNGSI UPGRADE: DETECT ZONA WAKTU OTOMATIS ---
  static Future<void> _sendTokenToBackend(String token) async {
    try {
      debugPrint("🚀 Mengirim token ke Python: $BACKEND_URL");
      
      // LOGIKA DETEKSI ZONA WAKTU HP
      // Kita cek selisih waktu HP dengan UTC (Greenwich)
      // WIB = UTC+7, WITA = UTC+8, WIT = UTC+9
      final int offsetJam = DateTime.now().timeZoneOffset.inHours;
      String zonaDetected = 'WIB'; // Default ke WIB

      if (offsetJam == 8) {
        zonaDetected = 'WITA';
      } else if (offsetJam == 9) {
        zonaDetected = 'WIT';
      }
      // Selain itu (offset 7 atau lainnya) dianggap WIB
      
      debugPrint("🕒 Zona Waktu Terdeteksi: $zonaDetected (Offset UTC+$offsetJam)");

      final response = await http.post(
        Uri.parse(BACKEND_URL),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "zona": zonaDetected 
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ SUKSES! Token tersimpan di Supabase via Python.");
      } else {
        debugPrint("❌ GAGAL: Python nolak. Code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ ERROR KONEKSI: Pastikan Laptop & HP connect internet.");
      debugPrint("Error detail: $e");
    }
  }
  // ------------------------------------

  static Future<String?> getToken() => _messaging.getToken();
  static Future<void> subscribeToTopic(String topic) => _messaging.subscribeToTopic(topic);
  static Future<void> unsubscribeFromTopic(String topic) => _messaging.unsubscribeFromTopic(topic);
}