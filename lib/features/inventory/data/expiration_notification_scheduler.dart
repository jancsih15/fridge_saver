import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/fridge_item.dart';

abstract class ExpirationNotificationScheduler {
  Future<void> initialize();
  Future<void> syncItemReminders(List<FridgeItem> items);
  Future<void> sendTestNotification();
}

class LocalExpirationNotificationScheduler
    implements ExpirationNotificationScheduler {
  LocalExpirationNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _now = now ?? DateTime.now;

  static const _channelId = 'expiry_reminders';
  static const _channelName = 'Expiry reminders';
  static const _channelDescription = 'Alerts before food items expire';
  static const _reminderHour = 9;
  static const _reminderDaysBefore = 2;
  static const _testNotificationId = 2147483000;

  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _now;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Keep default timezone location if resolving local timezone fails.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  @override
  Future<void> syncItemReminders(List<FridgeItem> items) async {
    await initialize();
    await _plugin.cancelAll();

    final now = _now();
    for (final item in items) {
      final remindAt = computeReminderDateTime(
        expirationDate: item.expirationDate,
        now: now,
        reminderDaysBefore: _reminderDaysBefore,
        reminderHour: _reminderHour,
      );

      if (remindAt == null) {
        continue;
      }

      final dateLabel = DateFormat('yyyy-MM-dd').format(item.expirationDate);
      await _plugin.zonedSchedule(
        _notificationId(item.id),
        'Food expiring soon',
        '${item.name} expires on $dateLabel',
        tz.TZDateTime.from(remindAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> sendTestNotification() async {
    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await androidPlugin?.areNotificationsEnabled() ?? true;
    if (!enabled) {
      await androidPlugin?.requestNotificationsPermission();
      final enabledAfterRequest =
          await androidPlugin?.areNotificationsEnabled() ?? false;
      if (!enabledAfterRequest) {
        throw StateError('Notification permission is disabled.');
      }
    }

    await _plugin.show(
      _testNotificationId,
      'Fridge Saver test notification',
      'If you see this, local notifications are working.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  int _notificationId(String id) {
    return notificationIdFromItemId(id);
  }
}

DateTime? computeReminderDateTime({
  required DateTime expirationDate,
  required DateTime now,
  int reminderDaysBefore = 2,
  int reminderHour = 9,
}) {
  final remindAt = DateTime(
    expirationDate.year,
    expirationDate.month,
    expirationDate.day,
    reminderHour,
  ).subtract(Duration(days: reminderDaysBefore));

  if (remindAt.isBefore(now)) {
    return null;
  }
  return remindAt;
}

int notificationIdFromItemId(String id) {
  var hash = 5381;
  for (final codeUnit in id.codeUnits) {
    hash = ((hash << 5) + hash) + codeUnit;
  }
  return hash & 0x7fffffff;
}
