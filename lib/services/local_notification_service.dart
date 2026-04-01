import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    // Use Asia/Seoul as default timezone
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (e) {
      // Fallback or debug print if location not found
      print('⚠️ [LocalNotificationService] Failed to set timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Request permissions for iOS
    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Request permissions for Android (13+)
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    debugPrint('🔔 [LocalNotificationService] Initialized & Permissions Requested');
  }

  // 일정 알림 스케줄링 (2시간 전)
  static Future<void> scheduleScheduleNotification({
    required int id,
    required String title,
    required DateTime scheduledTime,
  }) async {
    final notifyTime = scheduledTime.subtract(const Duration(hours: 2));
    
    // 이미 지난 시간이면 스킵
    if (notifyTime.isBefore(DateTime.now())) {
      print('🔔 [LocalNotificationService] Skip past notification for "$title" at $notifyTime');
      return;
    }

    await _plugin.zonedSchedule(
      id,
      '📅 일정 알림',
      '"$title" 일정이 2시간 후 시작됩니다.',
      tz.TZDateTime.from(notifyTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_channel',
          '일정 알림',
          channelDescription: '2시간 전 일정 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('✅ [LocalNotificationService] Scheduled notification for "$title" at $notifyTime');
  }

  // 일정 알림 취소
  static Future<void> cancelScheduleNotification(int id) async {
    await _plugin.cancel(id);
    print('🚫 [LocalNotificationService] Cancelled notification #$id');
  }

  // 알림 ID 생성 (제목 + 날짜 조합)
  static int generateId(String title, DateTime date) {
    return '${title}_${date.toIso8601String()}'.hashCode.abs();
  }
}
