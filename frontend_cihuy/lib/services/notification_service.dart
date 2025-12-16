import 'dart:io';
import 'dart:convert'; // [TAMBAHAN] Buat encode JSON
import 'package:http/http.dart' as http; // [TAMBAHAN] Buat request ke Railway
import 'package:firebase_messaging/firebase_messaging.dart'; // [TAMBAHAN] Ambil Token
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // ==========================================================
  // CONFIG LOCAL NOTIFICATION (Tampilan di HP)
  // ==========================================================
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'cihuy_reminder_channel';
  static const String _channelName = 'Pengingat CIHUY';
  static const String _channelDesc = 'Notifikasi dari Server Cihuy';

  static bool _initialized = false;

  // ==========================================================
  // CONFIG BACKEND (Koneksi ke Railway)
  // ==========================================================
  // Pastikan URL ini sesuai dengan URL Railway kamu
  static const String _baseUrl = "https://cihuy-controlitholdyourself-production.up.railway.app"; 

  // ---------------------------------------------
  // 1. INIT: Wajib ada biar notif bisa muncul di layar
  // ---------------------------------------------
  static Future<void> init() async {
    if (_initialized) return;

    // Pastikan icon 'ic_launcher' ada di folder android/app/src/main/res/mipmap-*
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings();

    final settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(settings);

    // Setup Channel Android (Penting buat Android 8+ biar ada suara & getar)
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max, // MAX = Muncul di atas layar (heads-up)
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  // ---------------------------------------------
  // 2. PERMISSIONS: Minta izin notifikasi (Android 13+ & iOS)
  // ---------------------------------------------
  static Future<bool> requestPermissions() async {
    bool granted = true;

    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (Platform.isAndroid) {
      final notif = await Permission.notification.status;
      if (!notif.isGranted) {
        final res = await Permission.notification.request();
        granted = res.isGranted;
      }
    }

    return granted;
  }

  // ---------------------------------------------
  // 3. SHOW IMMEDIATE: Fungsi ini dipanggil fcm_service.dart
  // ---------------------------------------------
  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ---------------------------------------------
  // 4. [BARU] UPLOAD TOKEN: Kirim Token HP ke Railway
  // Panggil fungsi ini setelah Login/Register Sukses!
  // ---------------------------------------------
  static Future<void> uploadToken(String zona) async {
    try {
      // A. Ambil Token dari Firebase (Langsung dari HP)
      String? token = await FirebaseMessaging.instance.getToken();

      if (token == null) {
        print("❌ Gagal dapat token FCM (Mungkin emulator error)");
        return;
      }

      print("🔥 Token HP Ini: $token"); // Cek Debug Console

      // B. Kirim ke Backend Python
      final url = Uri.parse('$_baseUrl/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "token": token,
          "zona": zona, // Contoh: "WIB", "WITA", "WIT"
        }),
      );

      if (response.statusCode == 200) {
        print("✅ SUKSES: Token berhasil disimpan di Server Railway!");
      } else {
        print("⚠️ GAGAL Server: ${response.body}");
      }
    } catch (e) {
      print("❌ Error Upload Token: $e");
    }
  }

  // Fungsi Cancel/Clear (Disimpan saja sebagai utility)
  static Future<void> cancelAll() async => _plugin.cancelAll();
}