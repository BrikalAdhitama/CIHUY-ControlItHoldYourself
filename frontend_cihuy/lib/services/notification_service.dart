import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyId = 100;
  static const String _prefKeyEnabled = 'notif_enabled';

  /// WAJIB dipanggil di main() sebelum runApp()
  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initSettings);
  }

  /// Dipakai SettingsScreen buat tahu switch awal ON / OFF
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? false;
  }

  /// Minta izin notif HANYA kalau belum granted.
  /// Dipanggil dari scheduleDaily8AM sebelum ngejadwalin notif.
  static Future<bool> requestPermissionIfNeeded() async {
    var status = await Permission.notification.status;

    if (status.isGranted) return true;

    status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Jadwalkan notifikasi harian jam 08:00 pagi
  static Future<void> scheduleDaily8AM() async {
    // pastikan user udah kasih izin
    final ok = await requestPermissionIfNeeded();
    if (!ok) {
      // user nolak permission → jangan set flag enabled
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, true);

    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8, // jam 08:00
      0,
    );

    // Kalau sudah lewat jam 8 hari ini, jadwalkan besok
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyId,
      'Mulai pagi dengan lebih sehat 💚',
      'Ingat lagi alasan kamu berhenti hari ini. Kamu masih di jalur yang benar!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminder',
          channelDescription: 'Pengingat harian untuk berhenti merokok/vape',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Matikan & hapus notifikasi harian
  static Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, false);
    await _plugin.cancel(_dailyId);
  }
}