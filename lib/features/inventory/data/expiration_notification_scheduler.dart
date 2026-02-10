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
  Future<List<ScheduledNotificationInfo>> getScheduledNotifications();
  Future<void> clearScheduledNotifications();
  Future<DateTime?> snoozeDailySummary({
    required List<FridgeItem> items,
    required int targetHour,
  });
}

class ScheduledNotificationInfo {
  const ScheduledNotificationInfo({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.scheduledFor,
  });

  final int id;
  final String? title;
  final String? body;
  final String type;
  final DateTime? scheduledFor;
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
  static const _typeItemReminder = 'item_reminder';
  static const _typeSummary = 'summary';
  static const _typeTest = 'test';
  static const _typeSnoozeConfirmation = 'snooze_confirmation';

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
    final hasPendingSummary = await _cancelManagedReminders();

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
        payload: _notificationPayload(
          type: _typeItemReminder,
          title: 'Food expiring soon',
          body: '${item.name} expires on $dateLabel',
          scheduledFor: remindAt,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    final summaryTime = computeNextDailySummaryTime(now: now);
    final summaryItems = itemsExpiringOnDate(items, summaryTime);
    if (summaryItems.isEmpty || hasPendingSummary) {
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
        scheduledFor: summaryTime,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<bool> _cancelManagedReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    var hasPendingSummary = false;
    for (final request in pending) {
      final payloadMap = notificationPayloadMap(request.payload);
      final type = _resolveNotificationType(request, payloadMap);
      if (type == _typeItemReminder) {
        await _plugin.cancel(request.id);
        continue;
      }
      if (type == _typeSummary) {
        if (!hasPendingSummary) {
          hasPendingSummary = true;
        } else {
          // Keep only one pending summary entry.
          await _plugin.cancel(request.id);
        }
      }
    }
    return hasPendingSummary;
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
      payload: _notificationPayload(
        type: _typeTest,
        title: 'Fridge Saver test notification',
        body: 'If you see this, local notifications are working.',
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
        scheduledFor: _now(),
      ),
    );
  }

  @override
  Future<List<ScheduledNotificationInfo>> getScheduledNotifications() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    final results = pending
        .map((request) {
          final payloadMap = notificationPayloadMap(request.payload);
          final type = _resolveNotificationType(request, payloadMap);
          final title = _resolveNotificationTitle(request, payloadMap, type);
          final body = _resolveNotificationBody(request, payloadMap);
          final scheduledFor = _resolveScheduledFor(
            request: request,
            payloadMap: payloadMap,
            type: type,
            body: body,
          );
          return ScheduledNotificationInfo(
            id: request.id,
            title: title,
            body: body,
            type: type,
            scheduledFor: scheduledFor,
          );
        })
        .toList(growable: false);

    results.sort((a, b) {
      final aTime = a.scheduledFor;
      final bTime = b.scheduledFor;
      if (aTime == null && bTime == null) {
        return a.id.compareTo(b.id);
      }
      if (aTime == null) {
        return 1;
      }
      if (bTime == null) {
        return -1;
      }
      return aTime.compareTo(bTime);
    });
    return results;
  }

  @override
  Future<void> clearScheduledNotifications() async {
    await initialize();
    await _plugin.cancelAll();
  }

  String _resolveNotificationType(
    PendingNotificationRequest request,
    Map<String, dynamic> payloadMap,
  ) {
    final payloadType = payloadMap['type'] as String?;
    if (payloadType != null && payloadType.isNotEmpty) {
      return payloadType;
    }
    if (request.id == _dailySummaryNotificationId) {
      return _typeSummary;
    }
    if (request.id == _testNotificationId) {
      return _typeTest;
    }
    if (request.id == _snoozeConfirmationNotificationId) {
      return _typeSnoozeConfirmation;
    }
    return _typeItemReminder;
  }

  String _resolveNotificationTitle(
    PendingNotificationRequest request,
    Map<String, dynamic> payloadMap,
    String type,
  ) {
    final payloadTitle = payloadMap['title'] as String?;
    if (request.title != null && request.title!.isNotEmpty) {
      return request.title!;
    }
    if (payloadTitle != null && payloadTitle.isNotEmpty) {
      return payloadTitle;
    }
    switch (type) {
      case _typeSummary:
        return 'Items expiring today';
      case _typeTest:
        return 'Fridge Saver test notification';
      case _typeSnoozeConfirmation:
        return 'Summary snoozed';
      default:
        return 'Food expiring soon';
    }
  }

  String _resolveNotificationBody(
    PendingNotificationRequest request,
    Map<String, dynamic> payloadMap,
  ) {
    final payloadBody = payloadMap['body'] as String?;
    if (request.body != null && request.body!.isNotEmpty) {
      return request.body!;
    }
    if (payloadBody != null && payloadBody.isNotEmpty) {
      return payloadBody;
    }
    return '';
  }

  DateTime? _resolveScheduledFor({
    required PendingNotificationRequest request,
    required Map<String, dynamic> payloadMap,
    required String type,
    required String body,
  }) {
    final payloadDate = scheduledForFromPayload(request.payload);
    if (payloadDate != null) {
      return payloadDate;
    }
    if (type != _typeItemReminder) {
      return null;
    }
    final match = RegExp(
      r'expires on (\d{4})-(\d{2})-(\d{2})',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) {
      return null;
    }
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return null;
    }
    final expirationDate = DateTime(year, month, day);
    return DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
      _reminderHour,
    ).subtract(Duration(days: _reminderDaysBefore));
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
    final payload = _summaryPayload(
      title: title,
      body: body,
      scheduledFor: null,
    );
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
      payload: _summaryPayload(
        title: summary.title,
        body: summary.body,
        scheduledFor: when,
      ),
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
      payload: _notificationPayload(
        type: _typeSnoozeConfirmation,
        title: 'Summary snoozed',
        body: 'Will remind again $dayLabel at $time.',
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

  String _summaryPayload({
    required String title,
    required String body,
    required DateTime? scheduledFor,
  }) {
    return _notificationPayload(
      type: _typeSummary,
      title: title,
      body: body,
      scheduledFor: scheduledFor,
    );
  }

  String _notificationPayload({
    required String type,
    required String title,
    required String body,
    DateTime? scheduledFor,
  }) {
    return jsonEncode({
      'type': type,
      'title': title,
      'body': body,
      if (scheduledFor != null) 'scheduled_for': scheduledFor.toIso8601String(),
    });
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

Map<String, dynamic> notificationPayloadMap(String? payload) {
  if (payload == null || payload.isEmpty) {
    return const <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // Ignore malformed payload.
  }
  return const <String, dynamic>{};
}

DateTime? scheduledForFromPayload(String? payload) {
  final map = notificationPayloadMap(payload);
  final raw = map['scheduled_for'] as String?;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
