import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'features/inventory/data/barcode_lookup_cache_repository.dart';
import 'features/inventory/data/barcode_lookup_service.dart';
import 'features/inventory/data/barcode_lookup_settings_repository.dart';
import 'features/inventory/data/expiration_notification_scheduler.dart';
import 'features/inventory/data/inventory_repository.dart';
import 'features/inventory/presentation/barcode_lookup_settings_controller.dart';
import 'features/inventory/presentation/inventory_controller.dart';
import 'features/inventory/presentation/inventory_screen.dart';

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
            final scheduler = LocalExpirationNotificationScheduler();
            scheduler.initialize();
            return scheduler;
          },
        ),
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
            notificationScheduler: context
                .read<ExpirationNotificationScheduler?>(),
          )..load(),
        ),
      ],
      child: MaterialApp(
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
