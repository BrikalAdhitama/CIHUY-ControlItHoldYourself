import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'cihuy_reminder_channel';
  static const String _channelName = 'Pengingat CIHUY';
  static const String _channelDesc = 'Notifikasi dari Server Cihuy';

  static bool _initialized = false;

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

  // Fungsi Cancel/Clear (Disimpan saja sebagai utility)
  static Future<void> cancelAll() async => _plugin.cancelAll();
}