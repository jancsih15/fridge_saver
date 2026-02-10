import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/expiration_notification_scheduler.dart';
import 'package:fridge_saver/features/inventory/domain/fridge_item.dart';

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

  group('computeNextDailySummaryTime', () {
    test('uses today when current time is before reminder hour', () {
      final next = computeNextDailySummaryTime(
        now: DateTime(2026, 2, 10, 8, 30),
        reminderHour: 9,
      );

      expect(next, DateTime(2026, 2, 10, 9));
    });

    test('uses tomorrow when current time is at or after reminder hour', () {
      final next = computeNextDailySummaryTime(
        now: DateTime(2026, 2, 10, 9, 0),
        reminderHour: 9,
      );

      expect(next, DateTime(2026, 2, 11, 9));
    });
  });

  group('itemsExpiringOnDate', () {
    test('returns only items matching target calendar day', () {
      final items = [
        FridgeItem(
          id: '1',
          name: 'Milk',
          quantity: 1,
          expirationDate: DateTime(2026, 2, 11, 16),
          location: StorageLocation.fridge,
        ),
        FridgeItem(
          id: '2',
          name: 'Yogurt',
          quantity: 1,
          expirationDate: DateTime(2026, 2, 12),
          location: StorageLocation.fridge,
        ),
      ];

      final result = itemsExpiringOnDate(items, DateTime(2026, 2, 11, 9));

      expect(result.map((item) => item.id), ['1']);
    });
  });

  group('dailySummaryTitle', () {
    test('formats singular and plural titles', () {
      expect(dailySummaryTitle(1), '1 item expires today');
      expect(dailySummaryTitle(3), '3 items expire today');
    });
  });

  group('dailySummaryBody', () {
    test('returns compact list with overflow marker', () {
      final items = [
        FridgeItem(
          id: '1',
          name: 'Milk',
          quantity: 1,
          expirationDate: DateTime(2026, 2, 11),
          location: StorageLocation.fridge,
        ),
        FridgeItem(
          id: '2',
          name: 'Yogurt',
          quantity: 1,
          expirationDate: DateTime(2026, 2, 11),
          location: StorageLocation.fridge,
        ),
        FridgeItem(
          id: '3',
          name: 'Cheese',
          quantity: 1,
          expirationDate: DateTime(2026, 2, 11),
          location: StorageLocation.fridge,
        ),
      ];

      expect(dailySummaryBody(items), 'Milk, Yogurt +1 more');
    });

    test('falls back when item names are empty', () {
      final items = [
        FridgeItem(
          id: '1',
          name: '   ',
          quantity: 1,
          expirationDate: DateTime(2026, 2, 11),
          location: StorageLocation.fridge,
        ),
      ];

      expect(dailySummaryBody(items), 'Check your expiring items.');
    });
  });

  group('computeSnoozeTime', () {
    test('returns today at target hour when still upcoming', () {
      final result = computeSnoozeTime(
        now: DateTime(2026, 2, 10, 10, 0),
        targetHour: 12,
      );
      expect(result, DateTime(2026, 2, 10, 12, 0));
    });

    test('returns tomorrow at target hour when already passed today', () {
      final result = computeSnoozeTime(
        now: DateTime(2026, 2, 10, 18, 0),
        targetHour: 17,
      );
      expect(result, DateTime(2026, 2, 11, 17, 0));
    });
  });
}
