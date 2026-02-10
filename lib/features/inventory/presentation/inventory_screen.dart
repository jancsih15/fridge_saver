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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Filter:'),
                  ...const [
                    (label: 'All', value: null),
                    (label: 'Today', value: 0),
                    (label: '1 day', value: 1),
                    (label: '3 days', value: 3),
                    (label: '7 days', value: 7),
                  ].map(
                    (option) => ChoiceChip(
                      label: Text(option.label),
                      selected: controller.expiringWithinDays == option.value,
                      onSelected: (_) {
                        context
                            .read<InventoryController>()
                            .setExpiringWithinDays(option.value);
                      },
                    ),
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
