import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/fridge_item.dart';
import 'add_item_screen.dart';
import 'app_settings_screen.dart';
import 'inventory_controller.dart';
import 'rapid_capture_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fridge Saver'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Expiry'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...const [
                                (label: 'All', value: null),
                                (label: 'Today', value: 0),
                                (label: '1d', value: 1),
                                (label: '3d', value: 3),
                                (label: '7d', value: 7),
                              ].map(
                                (option) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(option.label),
                                    selected:
                                        controller.expiringWithinDays ==
                                        option.value,
                                    onSelected: (_) {
                                      context
                                          .read<InventoryController>()
                                          .setExpiringWithinDays(option.value);
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<InventorySortBy>(
                          value: controller.sortBy,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                              value: InventorySortBy.expirationSoonest,
                              child: Text('Soonest'),
                            ),
                            DropdownMenuItem(
                              value: InventorySortBy.expirationLatest,
                              child: Text('Latest'),
                            ),
                            DropdownMenuItem(
                              value: InventorySortBy.nameAZ,
                              child: Text('Name A-Z'),
                            ),
                            DropdownMenuItem(
                              value: InventorySortBy.nameZA,
                              child: Text('Name Z-A'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              context.read<InventoryController>().setSortBy(
                                value,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Location'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...const [
                                (label: 'All', value: null),
                                (
                                  label: 'Fridge',
                                  value: StorageLocation.fridge,
                                ),
                                (
                                  label: 'Freezer',
                                  value: StorageLocation.freezer,
                                ),
                                (
                                  label: 'Pantry',
                                  value: StorageLocation.pantry,
                                ),
                              ].map(
                                (option) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(option.label),
                                    selected:
                                        controller.locationFilter ==
                                        option.value,
                                    onSelected: (_) {
                                      context
                                          .read<InventoryController>()
                                          .setLocationFilter(option.value);
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: controller.visibleItems.isEmpty
                ? const Center(
                    child: Text('No items yet. Add your first item.'),
                  )
                : ListView.separated(
                    itemCount: controller.visibleItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = controller.visibleItems[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          final deleted = await context
                              .read<InventoryController>()
                              .deleteItem(item.id);
                          if (deleted == null || !context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('${item.name} deleted'),
                                duration: const Duration(seconds: 4),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () {
                                    context
                                        .read<InventoryController>()
                                        .restoreDeletedItem(deleted);
                                  },
                                ),
                              ),
                            );
                        },
                        child: ListTile(
                          onTap: () => _openEditItem(context, item),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.location.name} - Qty ${item.quantity} - Expires ${DateFormat.yMMMd().format(item.expirationDate)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit item',
                            onPressed: () => _openEditItem(context, item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'rapidCapture',
            onPressed: () => _openRapidCapture(context),
            icon: const Icon(Icons.bolt),
            label: const Text('Rapid capture'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'addItem',
            onPressed: () => _openAddItem(context),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRapidCapture(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RapidCaptureScreen()));
  }

  Future<void> _openAddItem(BuildContext context) async {
    final input = await Navigator.of(context).push<AddItemInput>(
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );

    if (input == null || !context.mounted) {
      return;
    }

    await context.read<InventoryController>().addItem(
      name: input.name,
      barcode: input.barcode,
      quantity: input.quantity,
      expirationDate: input.expirationDate,
      location: input.location,
    );
  }

  Future<void> _openEditItem(BuildContext context, FridgeItem item) async {
    final input = await Navigator.of(context).push<AddItemInput>(
      MaterialPageRoute(builder: (_) => AddItemScreen(initialItem: item)),
    );

    if (input == null || !context.mounted) {
      return;
    }

    await context.read<InventoryController>().updateItem(
      id: item.id,
      name: input.name,
      barcode: input.barcode,
      quantity: input.quantity,
      expirationDate: input.expirationDate,
      location: input.location,
    );
  }
}
