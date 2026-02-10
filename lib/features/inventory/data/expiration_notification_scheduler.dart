import 'dart:convert';

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
  Future<void> sendDailySummaryTestNotification(List<FridgeItem> items);
  Future<DateTime?> snoozeDailySummary({
    required List<FridgeItem> items,
    required int targetHour,
  });
}

class LocalExpirationNotificationScheduler
    implements ExpirationNotificationScheduler {
  LocalExpirationNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? now,
    Future<void> Function()? onOpenExpiringToday,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _now = now ?? DateTime.now,
       _onOpenExpiringToday = onOpenExpiringToday;

  static const _channelId = 'expiry_reminders';
  static const _channelName = 'Expiry reminders';
  static const _channelDescription = 'Alerts before food items expire';
  static const _reminderHour = 9;
  static const _reminderDaysBefore = 2;
  static const _testNotificationId = 2147483000;
  static const _dailySummaryNotificationId = 2147483001;
  static const _snoozeConfirmationNotificationId = 2147483002;
  static const _summaryActionOpen = 'open_expiring';
  static const _summaryActionSnoozeNoon = 'snooze_noon';
  static const _summaryActionSnoozeEvening = 'snooze_evening';

  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _now;
  final Future<void> Function()? _onOpenExpiringToday;
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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationTap,
    );

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

    final summaryTime = computeNextDailySummaryTime(now: now);
    final summaryItems = itemsExpiringOnDate(items, summaryTime);
    if (summaryItems.isEmpty) {
      return;
    }

    await _plugin.zonedSchedule(
      _dailySummaryNotificationId,
      dailySummaryTitle(summaryItems.length),
      dailySummaryBody(summaryItems),
      tz.TZDateTime.from(summaryTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: const [
            AndroidNotificationAction(
              _summaryActionOpen,
              'Open expiring items',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              _summaryActionSnoozeNoon,
              'Snooze to 12:00',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              _summaryActionSnoozeEvening,
              'Snooze to 17:00',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      payload: _summaryPayload(
        title: dailySummaryTitle(summaryItems.length),
        body: dailySummaryBody(summaryItems),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> sendTestNotification() async {
    await initialize();
    await _ensureNotificationPermission();

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

  @override
  Future<void> sendDailySummaryTestNotification(List<FridgeItem> items) async {
    await initialize();
    await _ensureNotificationPermission();

    await _plugin.show(
      _dailySummaryNotificationId,
      '[QA] ${dailySummaryTitle(items.length)}',
      dailySummaryBody(items),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: const [
            AndroidNotificationAction(
              _summaryActionOpen,
              'Open expiring items',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              _summaryActionSnoozeNoon,
              'Snooze to 12:00',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              _summaryActionSnoozeEvening,
              'Snooze to 17:00',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      payload: _summaryPayload(
        title: dailySummaryTitle(items.length),
        body: dailySummaryBody(items),
      ),
    );
  }

  @override
  Future<DateTime?> snoozeDailySummary({
    required List<FridgeItem> items,
    required int targetHour,
  }) async {
    await initialize();
    await _ensureNotificationPermission();

    final summaryItems = itemsExpiringOnDate(items, _now());
    final title = dailySummaryTitle(summaryItems.length);
    final body = dailySummaryBody(summaryItems);
    final payload = _summaryPayload(title: title, body: body);
    final when = await _scheduleSnooze(
      payload,
      targetHour: targetHour,
      showConfirmation: true,
    );
    return when;
  }

  int _notificationId(String id) {
    return notificationIdFromItemId(id);
  }

  Future<void> _ensureNotificationPermission() async {
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
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final actionId = response.actionId;
    if (actionId == _summaryActionSnoozeNoon) {
      await _scheduleSnooze(
        response.payload,
        targetHour: 12,
        showConfirmation: true,
      );
      return;
    }
    if (actionId == _summaryActionSnoozeEvening) {
      await _scheduleSnooze(
        response.payload,
        targetHour: 17,
        showConfirmation: true,
      );
      return;
    }

    await _onOpenExpiringToday?.call();
  }

  Future<DateTime> _scheduleSnooze(
    String? payload, {
    required int targetHour,
    bool showConfirmation = false,
  }) async {
    final summary = _summaryFromPayload(payload);
    final now = _now();
    final when = computeSnoozeTime(now: now, targetHour: targetHour);

    await _plugin.zonedSchedule(
      _dailySummaryNotificationId,
      summary.title,
      summary.body,
      tz.TZDateTime.from(when, tz.local),
      _summaryNotificationDetails(),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    if (showConfirmation) {
      await _sendSnoozeConfirmation(when);
    }
    return when;
  }

  NotificationDetails _summaryNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            _summaryActionOpen,
            'Open expiring items',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            _summaryActionSnoozeNoon,
            'Snooze to 12:00',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            _summaryActionSnoozeEvening,
            'Snooze to 17:00',
            showsUserInterface: true,
          ),
        ],
      ),
    );
  }

  Future<void> _sendSnoozeConfirmation(DateTime when) async {
    final time = DateFormat('HH:mm').format(when);
    final dayLabel = _relativeDayLabel(now: _now(), when: when);
    await _plugin.show(
      _snoozeConfirmationNotificationId,
      'Summary snoozed',
      'Will remind again $dayLabel at $time.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  String _relativeDayLabel({required DateTime now, required DateTime when}) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    if (target == today) {
      return 'today';
    }
    if (target == today.add(const Duration(days: 1))) {
      return 'tomorrow';
    }
    return 'on ${DateFormat('yyyy-MM-dd').format(when)}';
  }

  String _summaryPayload({required String title, required String body}) {
    return jsonEncode({'type': 'summary', 'title': title, 'body': body});
  }

  _SummaryPayload _summaryFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return const _SummaryPayload(
        title: 'Items expiring today',
        body: 'Check your expiring items.',
      );
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final title = decoded['title'] as String?;
        final body = decoded['body'] as String?;
        if (title != null &&
            title.isNotEmpty &&
            body != null &&
            body.isNotEmpty) {
          return _SummaryPayload(title: title, body: body);
        }
      }
    } catch (_) {
      // Ignore malformed payload and use fallback text.
    }
    return const _SummaryPayload(
      title: 'Items expiring today',
      body: 'Check your expiring items.',
    );
  }
}

@pragma('vm:entry-point')
void _backgroundNotificationTap(NotificationResponse response) {}

class _SummaryPayload {
  const _SummaryPayload({required this.title, required this.body});

  final String title;
  final String body;
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

DateTime computeNextDailySummaryTime({
  required DateTime now,
  int reminderHour = 9,
}) {
  final todayAtHour = DateTime(now.year, now.month, now.day, reminderHour);
  if (now.isBefore(todayAtHour)) {
    return todayAtHour;
  }
  final tomorrow = now.add(const Duration(days: 1));
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, reminderHour);
}

List<FridgeItem> itemsExpiringOnDate(List<FridgeItem> items, DateTime date) {
  final target = DateTime(date.year, date.month, date.day);
  return items
      .where((item) {
        final itemDate = DateTime(
          item.expirationDate.year,
          item.expirationDate.month,
          item.expirationDate.day,
        );
        return itemDate == target;
      })
      .toList(growable: false);
}

String dailySummaryTitle(int count) {
  if (count == 1) {
    return '1 item expires today';
  }
  return '$count items expire today';
}

String dailySummaryBody(List<FridgeItem> items, {int previewCount = 2}) {
  if (items.isEmpty) {
    return 'Check your expiring items.';
  }

  final names = items
      .map((item) => item.name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) {
    return 'Check your expiring items.';
  }

  final visible = names.take(previewCount).join(', ');
  final remaining = names.length - previewCount;
  if (remaining > 0) {
    return '$visible +$remaining more';
  }
  return visible;
}

DateTime computeSnoozeTime({required DateTime now, required int targetHour}) {
  final todayAtHour = DateTime(now.year, now.month, now.day, targetHour);
  if (now.isBefore(todayAtHour)) {
    return todayAtHour;
  }
  final tomorrow = now.add(const Duration(days: 1));
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, targetHour);
}
