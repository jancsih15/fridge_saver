import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/domain/fridge_item.dart';

void main() {
  test('FridgeItem toMap and fromMap roundtrip', () {
    final item = FridgeItem(
      id: 'abc',
      name: 'Milk',
      barcode: '599123',
      quantity: 2,
      expirationDate: DateTime(2026, 2, 15),
      location: StorageLocation.fridge,
    );

    final map = item.toMap();
    final restored = FridgeItem.fromMap(map);

    expect(restored.id, item.id);
    expect(restored.name, item.name);
    expect(restored.barcode, item.barcode);
    expect(restored.quantity, item.quantity);
    expect(restored.expirationDate, item.expirationDate);
    expect(restored.location, item.location);
  });

  test('FridgeItem fromMap supports null barcode', () {
    final restored = FridgeItem.fromMap({
      'id': 'x1',
      'name': 'Rice',
      'barcode': null,
      'quantity': 1,
      'expirationDate': DateTime(2026, 3, 1).toIso8601String(),
      'location': 'pantry',
    });

    expect(restored.barcode, isNull);
    expect(restored.location, StorageLocation.pantry);
  });
}
