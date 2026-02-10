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
      body: SafeArea(
        bottom: false,
        child: !controller.loaded
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enable and reorder free providers. Top providers are used first.',
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: controller.order.length,
                        onReorder: controller.reorderProvider,
                        itemBuilder: (context, index) {
                          final provider = controller.order[index];
                          return ListTile(
                            key: ValueKey(provider.id),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_indicator, size: 20),
                            ),
                            title: Text(provider.label),
                            subtitle: Text(provider.host, maxLines: 1),
                            trailing: Switch(
                              value: controller.isEnabled(provider),
                              onChanged: (value) =>
                                  controller.toggleProvider(provider, value),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: controller.loaded
          ? SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
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
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore defaults'),
                    ),
                    OutlinedButton.icon(
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
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Clear barcode cache'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
