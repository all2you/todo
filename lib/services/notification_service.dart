import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'daily_diary_reminder';
  static const _notifId = 1;
  static const _enabledKey = 'notif_enabled';
  static const _hourKey = 'notif_hour';
  static const _minuteKey = 'notif_minute';

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _plugin.cancel(_notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      '하루 일기 알림',
      channelDescription: '매일 일기 작성을 도와주는 알림입니다.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      _notifId,
      '오늘 하루를 기록해볼까요? 📖',
      _getDailyMessage(),
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(_notifId);
  }

  /// "작년 오늘" 같은 과거 기록이 있을 때 즉시 로컬 알림을 표시.
  static Future<void> showOnThisDay({
    required int yearsAgo,
    required String entryTitle,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_diary_on_this_day',
      '작년 오늘',
      channelDescription: '과거의 같은 날에 작성한 일기를 알려줍니다.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final title = yearsAgo == 1 ? '작년 오늘의 일기 📖' : '$yearsAgo년 전 오늘의 일기 📖';
    await _plugin.show(2, title, '"$entryTitle"을(를) 다시 읽어보세요', details);
  }

  // 설정 저장/불러오기
  static Future<void> saveSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }

  static Future<({bool enabled, int hour, int minute})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 21,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  static String _getDailyMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '좋은 아침이에요! 오늘 하루도 소중하게 기록해요 ☀️';
    if (hour < 18) return '오늘 오후는 어떠셨나요? 지금 기록해보세요 🌿';
    return '오늘 하루 어떠셨나요? 잠들기 전 기록해두세요 🌙';
  }
}
