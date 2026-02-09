import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/inventory/data/inventory_repository.dart';
import 'features/inventory/presentation/inventory_controller.dart';
import 'features/inventory/presentation/inventory_screen.dart';

class FridgeSaverApp extends StatelessWidget {
  const FridgeSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InventoryController(
        repository: HiveInventoryRepository(),
      )..load(),
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
