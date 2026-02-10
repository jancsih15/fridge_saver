import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/expiration_notification_scheduler.dart';
import 'inventory_controller.dart';

class DebugToolsScreen extends StatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  State<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugToolsScreenState extends State<DebugToolsScreen> {
  late Future<List<ScheduledNotificationInfo>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
  }

  Future<List<ScheduledNotificationInfo>> _loadPending() async {
    final scheduler = context.read<ExpirationNotificationScheduler?>();
    if (scheduler == null) {
      return const [];
    }
    return scheduler.getScheduledNotifications();
  }

  void _refreshPending() {
    setState(() {
      _pendingFuture = _loadPending();
    });
  }

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
                      _refreshPending();
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
                      _refreshPending();
                    },
                    icon: const Icon(Icons.summarize_outlined),
                    label: const Text('Send daily summary QA notification'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Scheduled notifications',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Clear scheduled notifications',
                        onPressed: () async {
                          await scheduler.clearScheduledNotifications();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Scheduled notifications cleared.'),
                            ),
                          );
                          _refreshPending();
                        },
                        icon: const Icon(Icons.delete_sweep_outlined),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refreshPending,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<ScheduledNotificationInfo>>(
                    future: _pendingFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Failed to load scheduled notifications.');
                      }

                      final data = snapshot.data ?? const [];
                      if (data.isEmpty) {
                        return const Text('No scheduled notifications.');
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = data[index];
                            final timeLabel = item.scheduledFor == null
                                ? 'time unknown'
                                : DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(item.scheduledFor!);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${item.id} - ${item.type}',
                                style: const TextStyle(
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              subtitle: Text(
                                '${item.title ?? '(no title)'}\n$timeLabel',
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
