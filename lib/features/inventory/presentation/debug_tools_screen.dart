import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/expiration_notification_scheduler.dart';
import 'inventory_controller.dart';

class DebugToolsScreen extends StatelessWidget {
  const DebugToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduler = context.watch<ExpirationNotificationScheduler?>();
    final controller = context.watch<InventoryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Debug Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use these helpers for manual QA. Keep this section lightweight and development-focused.',
            ),
            const SizedBox(height: 16),
            if (scheduler == null)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Notifications unavailable'),
                subtitle: Text(
                  'Local notification testing is not available on web.',
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await scheduler.sendTestNotification();
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications are disabled. Please allow notifications for this app.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test notification sent.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Send test notification now'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final expiringToday = itemsExpiringOnDate(
                        controller.allItems,
                        DateTime.now(),
                      );

                      try {
                        await scheduler.sendDailySummaryTestNotification(
                          expiringToday,
                        );
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications are disabled. Please allow notifications for this app.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (!context.mounted) {
                        return;
                      }
                      final count = expiringToday.length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Daily summary QA notification sent ($count expiring today).',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.summarize_outlined),
                    label: const Text('Send daily summary QA notification'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
