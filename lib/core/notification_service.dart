import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a notification at a specific date/time (9:00 AM on event day)
  Future<void> scheduleNotification({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
  }) async {
    // Schedule at 9:00 AM on the day of the event
    final notifyAt = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9, // 오전 9시
      0,
    );

    // If the notification time has already passed, don't schedule
    if (notifyAt.isBefore(DateTime.now())) {
      debugPrint('[NotificationService] Skipping past notification: $notifyAt');
      return;
    }

    // Calculate delay from now
    final delay = notifyAt.difference(DateTime.now());

    const androidDetails = AndroidNotificationDetails(
      'pawprint_schedule',
      '일정 알림',
      channelDescription: '캘린더 일정 알림',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use a delayed future to show the notification at the right time.
    // For production, you'd want to use zonedSchedule with timezone package.
    // This approach works well for short-to-medium delays.
    Future.delayed(delay, () async {
      try {
        await _plugin.show(id, title, body, details);
        debugPrint('[NotificationService] Showed notification #$id');
      } catch (e) {
        debugPrint('[NotificationService] Failed to show notification: $e');
      }
    });

    debugPrint('[NotificationService] Scheduled notification #$id at $notifyAt (in ${delay.inHours}h)');
  }

  /// Cancel a notification by ID
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    debugPrint('[NotificationService] Cancelled notification #$id');
  }
}
