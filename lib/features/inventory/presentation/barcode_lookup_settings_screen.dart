import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/barcode_lookup_models.dart';
import 'barcode_lookup_settings_controller.dart';

class BarcodeLookupSettingsScreen extends StatefulWidget {
  const BarcodeLookupSettingsScreen({super.key});

  @override
  State<BarcodeLookupSettingsScreen> createState() =>
      _BarcodeLookupSettingsScreenState();
}

class _BarcodeLookupSettingsScreenState
    extends State<BarcodeLookupSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<BarcodeLookupSettingsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BarcodeLookupSettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Providers')),
      body: !controller.loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enable and reorder free providers. Top providers are used first.',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: controller.order.length,
                      onReorder: controller.reorderProvider,
                      itemBuilder: (context, index) {
                        final provider = controller.order[index];
                        return SwitchListTile(
                          key: ValueKey(provider.id),
                          title: Text(provider.label),
                          subtitle: Text(provider.host),
                          value: controller.isEnabled(provider),
                          onChanged: (value) =>
                              controller.toggleProvider(provider, value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await controller.restoreDefaults();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Provider defaults restored'),
                            ),
                          );
                        },
                        child: const Text('Restore defaults'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await controller.clearCache();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Barcode cache cleared'),
                            ),
                          );
                        },
                        child: const Text('Clear barcode cache'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
