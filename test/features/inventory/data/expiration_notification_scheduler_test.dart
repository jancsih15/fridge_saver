import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/expiration_notification_scheduler.dart';

void main() {
  group('computeReminderDateTime', () {
    test('returns reminder date at configured hour and lead days', () {
      final now = DateTime(2026, 2, 10, 8);
      final expiration = DateTime(2026, 2, 14);

      final remindAt = computeReminderDateTime(
        expirationDate: expiration,
        now: now,
        reminderDaysBefore: 2,
        reminderHour: 9,
      );

      expect(remindAt, DateTime(2026, 2, 12, 9));
    });

    test('returns null when reminder time is already in the past', () {
      final now = DateTime(2026, 2, 13, 10);
      final expiration = DateTime(2026, 2, 14);

      final remindAt = computeReminderDateTime(
        expirationDate: expiration,
        now: now,
      );

      expect(remindAt, isNull);
    });
  });

  group('notificationIdFromItemId', () {
    test('returns stable positive id for same item id', () {
      final first = notificationIdFromItemId('item-123');
      final second = notificationIdFromItemId('item-123');

      expect(first, second);
      expect(first, greaterThanOrEqualTo(0));
    });

    test('returns different ids for different item ids', () {
      final first = notificationIdFromItemId('item-1');
      final second = notificationIdFromItemId('item-2');

      expect(first, isNot(second));
    });
  });
}
