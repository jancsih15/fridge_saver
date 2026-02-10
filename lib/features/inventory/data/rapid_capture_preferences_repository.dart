import 'package:hive/hive.dart';

import '../domain/fridge_item.dart';

class RapidCapturePreferencesRepository {
  RapidCapturePreferencesRepository({Box<dynamic>? box})
    : _box = box ?? Hive.box('app_settings');

  static const _lastLocationKey = 'rapid_capture_last_location';
  static const _quantityPrefix = 'rapid_capture_qty_';

  final Box<dynamic> _box;

  Future<StorageLocation> loadLastLocation() async {
    final raw = _box.get(_lastLocationKey);
    if (raw is String) {
      return StorageLocation.values.firstWhere(
        (loc) => loc.name == raw,
        orElse: () => StorageLocation.fridge,
      );
    }
    return StorageLocation.fridge;
  }

  Future<void> saveLastLocation(StorageLocation location) async {
    await _box.put(_lastLocationKey, location.name);
  }

  Future<int?> loadRememberedQuantity(String barcode) async {
    final value = _box.get('$_quantityPrefix$barcode');
    if (value is int && value > 0) {
      return value;
    }
    return null;
  }

  Future<void> saveRememberedQuantity(String barcode, int quantity) async {
    if (quantity < 1) {
      await _box.delete('$_quantityPrefix$barcode');
      return;
    }
    await _box.put('$_quantityPrefix$barcode', quantity);
  }
}
