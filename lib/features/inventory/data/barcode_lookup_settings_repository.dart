import 'package:hive/hive.dart';

import 'barcode_lookup_models.dart';

class BarcodeLookupSettings {
  const BarcodeLookupSettings({
    required this.orderedProviders,
    required this.enabledProviders,
  });

  final List<BarcodeLookupProvider> orderedProviders;
  final Set<BarcodeLookupProvider> enabledProviders;
}

class BarcodeLookupSettingsRepository {
  BarcodeLookupSettingsRepository({Box<dynamic>? box})
    : _box = box ?? Hive.box('app_settings');

  static const _orderKey = 'barcode_lookup_order_v1';
  static const _enabledKey = 'barcode_lookup_enabled_v1';

  final Box<dynamic> _box;

  Future<BarcodeLookupSettings> loadSettings() async {
    final rawOrder = _box.get(_orderKey);
    final rawEnabled = _box.get(_enabledKey);

    final defaultOrder = List<BarcodeLookupProvider>.from(
      BarcodeLookupProvider.values,
    );
    final order = <BarcodeLookupProvider>[];
    final seen = <BarcodeLookupProvider>{};

    if (rawOrder is List) {
      for (final item in rawOrder) {
        if (item is! String) {
          continue;
        }
        final provider = barcodeProviderFromId(item);
        if (provider == null || seen.contains(provider)) {
          continue;
        }
        order.add(provider);
        seen.add(provider);
      }
    }

    for (final provider in defaultOrder) {
      if (!seen.contains(provider)) {
        order.add(provider);
      }
    }

    final enabled = <BarcodeLookupProvider>{};
    if (rawEnabled is List) {
      for (final item in rawEnabled) {
        if (item is! String) {
          continue;
        }
        final provider = barcodeProviderFromId(item);
        if (provider != null) {
          enabled.add(provider);
        }
      }
    } else {
      enabled.addAll(defaultOrder);
    }

    if (enabled.isEmpty) {
      enabled.addAll(defaultOrder);
    }

    return BarcodeLookupSettings(
      orderedProviders: order,
      enabledProviders: enabled,
    );
  }

  Future<void> saveSettings(BarcodeLookupSettings settings) async {
    await _box.put(
      _orderKey,
      settings.orderedProviders.map((p) => p.id).toList(growable: false),
    );
    await _box.put(
      _enabledKey,
      settings.enabledProviders.map((p) => p.id).toList(growable: false),
    );
  }
}
