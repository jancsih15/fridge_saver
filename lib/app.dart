import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'features/inventory/data/barcode_lookup_cache_repository.dart';
import 'features/inventory/data/barcode_lookup_service.dart';
import 'features/inventory/data/barcode_lookup_settings_repository.dart';
import 'features/inventory/data/expiring_filter_settings_repository.dart';
import 'features/inventory/data/expiration_notification_scheduler.dart';
import 'features/inventory/data/inventory_repository.dart';
import 'features/inventory/presentation/barcode_lookup_settings_controller.dart';
import 'features/inventory/presentation/inventory_controller.dart';
import 'features/inventory/presentation/inventory_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class FridgeSaverApp extends StatelessWidget {
  const FridgeSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ExpirationNotificationScheduler?>(
          create: (_) {
            if (kIsWeb) {
              return null;
            }
            final scheduler = LocalExpirationNotificationScheduler(
              onOpenExpiringToday: () async {
                appNavigatorKey.currentState?.popUntil(
                  (route) => route.isFirst,
                );
                final currentContext = appNavigatorKey.currentContext;
                if (currentContext != null) {
                  await currentContext
                      .read<InventoryController>()
                      .setExpiringWithinDays(0);
                }
              },
            );
            scheduler.initialize();
            return scheduler;
          },
        ),
        Provider(create: (_) => ExpiringFilterSettingsRepository()),
        Provider(create: (_) => BarcodeLookupSettingsRepository()),
        Provider(create: (_) => BarcodeLookupCacheRepository()),
        ProxyProvider2<
          BarcodeLookupSettingsRepository,
          BarcodeLookupCacheRepository,
          BarcodeLookupService
        >(
          update: (_, settingsRepo, cacheRepo, __) => BarcodeLookupService(
            settingsRepository: settingsRepo,
            cacheRepository: cacheRepo,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => BarcodeLookupSettingsController(
            settingsRepository: context.read<BarcodeLookupSettingsRepository>(),
            cacheRepository: context.read<BarcodeLookupCacheRepository>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => InventoryController(
            repository: HiveInventoryRepository(),
            filterSettingsRepository: context
                .read<ExpiringFilterSettingsRepository>(),
            notificationScheduler: context
                .read<ExpirationNotificationScheduler?>(),
          )..load(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Fridge Saver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const InventoryScreen(),
      ),
    );
  }
}
