// lib/services/fcm_service.dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Import service sebelah yang sudah kita upgrade tadi
import 'notification_service.dart';

/// HANDLER BACKGROUND
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FcmService] Background message: ${message.messageId}');
  // Jangan panggil showImmediate di sini, Android otomatis nanganin notif background
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      // Set handler background
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Izin untuk iOS
      if (Platform.isIOS) {
        await _messaging.requestPermission(
          alert: true, badge: true, sound: true,
        );
      }

      // --- FOREGROUND HANDLER (Saat Aplikasi Dibuka) ---
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          final notif = message.notification;
          final title = notif?.title ?? 'CIHUY';
          final body = notif?.body ?? (message.data['body'] ?? '');
          
          // Tampilkan Notif pakai Service sebelah
          NotificationService.showImmediate(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: title,
            body: body,
            payload: message.data.isNotEmpty ? message.data.toString() : null,
          );
        } catch (e) {
          debugPrint('[FcmService] onMessage error: $e');
        }
      });

      // --- BAGIAN PENTING: SETOR TOKEN OTOMATIS ---
      // Kita manfaatkan logic deteksi zona di sini, lalu oper ke NotificationService
      final token = await _messaging.getToken();
      
      if (token != null) {
        // 1. Deteksi Zona Waktu
        final int offsetJam = DateTime.now().timeZoneOffset.inHours;
        String zonaDetected = 'WIB'; 
        if (offsetJam == 8) zonaDetected = 'WITA';
        if (offsetJam == 9) zonaDetected = 'WIT';

        debugPrint("🕒 Auto Detect Zona: $zonaDetected");

        // 2. Panggil fungsi sakti dari NotificationService
        // Gak perlu coding HTTP lagi disini, biar rapi!
        await NotificationService.uploadToken(zonaDetected);
      }

    } catch (e) {
      debugPrint('[FcmService] init error: $e');
    }
  }

  static Future<String?> getToken() => _messaging.getToken();
}