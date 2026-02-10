import 'package:flutter/material.dart';

import 'barcode_lookup_settings_screen.dart';
import 'debug_tools_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_scanner_outlined),
            title: const Text('Barcode Providers'),
            subtitle: const Text(
              'Enable providers, set lookup order, and clear lookup cache.',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BarcodeLookupSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.developer_mode_outlined),
            title: const Text('Debug Tools'),
            subtitle: const Text('Manual QA utilities like test notification.'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugToolsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
