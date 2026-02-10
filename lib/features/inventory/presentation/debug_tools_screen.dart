import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/expiration_notification_scheduler.dart';

class DebugToolsScreen extends StatelessWidget {
  const DebugToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduler = context.watch<ExpirationNotificationScheduler?>();

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
                    const SnackBar(content: Text('Test notification sent.')),
                  );
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Send test notification now'),
              ),
          ],
        ),
      ),
    );
  }
}
