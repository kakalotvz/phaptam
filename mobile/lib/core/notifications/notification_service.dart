import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/content/content_models.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> syncScriptureReminders(List<ScriptureReminder> reminders) async {
    await init();
    await _plugin.cancelAll();
    for (final reminder in reminders.where((item) => item.active)) {
      await _scheduleReminder(reminder);
    }
  }

  Future<void> _scheduleReminder(ScriptureReminder reminder) async {
    final weekdays = reminder.weekdays.isEmpty
        ? const {1, 2, 3, 4, 5, 6, 7}
        : reminder.weekdays;
    for (final weekday in weekdays) {
      final id = reminder.id.hashCode.abs() % 100000 + weekday;
      await _plugin.zonedSchedule(
        id: id,
        title: reminder.title,
        body: reminder.scripture.title,
        scheduledDate: _nextInstance(weekday, reminder.timeOfDay),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'scripture_reminders',
            'Lịch tụng kinh',
            channelDescription: 'Nhắc giờ đọc kinh đã đặt trong ứng dụng',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  tz.TZDateTime _nextInstance(int weekday, Duration timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.inHours.remainder(24),
      timeOfDay.inMinutes.remainder(60),
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
