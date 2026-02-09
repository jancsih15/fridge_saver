import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/fridge_item.dart';
import 'add_item_screen.dart';
import 'inventory_controller.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InventoryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Fridge Saver')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Expiring within 3 days'),
            value: controller.expiringSoonOnly,
            onChanged: controller.setExpiringSoonOnly,
          ),
          Expanded(
            child: controller.visibleItems.isEmpty
                ? const Center(child: Text('No items yet. Add your first item.'))
                : ListView.separated(
                    itemCount: controller.visibleItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = controller.visibleItems[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.location.name} • Qty ${item.quantity} • Expires ${DateFormat.yMMMd().format(item.expirationDate)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItem(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
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
}
