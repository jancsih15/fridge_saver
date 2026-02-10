import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/expiration_notification_scheduler.dart';
import 'inventory_controller.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduler = context.watch<ExpirationNotificationScheduler?>();
    final controller = context.watch<InventoryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Snooze the daily summary manually if you opened the app and want to be reminded later.',
          ),
          const SizedBox(height: 16),
          if (scheduler == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('Notifications unavailable'),
              subtitle: Text('Local notifications are not available on web.'),
            )
          else ...[
            FilledButton.tonalIcon(
              onPressed: () async {
                final when = await scheduler.snoozeDailySummary(
                  items: controller.allItems,
                  targetHour: 12,
                );
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      when == null
                          ? 'Could not snooze summary.'
                          : 'Summary snoozed to ${_whenLabel(when, DateTime.now())} ${_two(when.hour)}:${_two(when.minute)}.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.snooze_outlined),
              label: const Text('Snooze daily summary to 12:00'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final when = await scheduler.snoozeDailySummary(
                  items: controller.allItems,
                  targetHour: 17,
                );
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      when == null
                          ? 'Could not snooze summary.'
                          : 'Summary snoozed to ${_whenLabel(when, DateTime.now())} ${_two(when.hour)}:${_two(when.minute)}.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.snooze_outlined),
              label: const Text('Snooze daily summary to 17:00'),
            ),
          ],
        ],
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _whenLabel(DateTime when, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(when.year, when.month, when.day);
  if (target == today) {
    return 'today';
  }
  if (target == today.add(const Duration(days: 1))) {
    return 'tomorrow';
  }
  return '${when.year}-${_two(when.month)}-${_two(when.day)}';
}
