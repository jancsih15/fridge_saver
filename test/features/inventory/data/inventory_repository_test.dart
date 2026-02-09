import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fridge_saver/features/inventory/data/inventory_repository.dart';
import 'package:fridge_saver/features/inventory/domain/fridge_item.dart';

void main() {
  group('HiveInventoryRepository', () {
    late Directory tempDir;
    late Box<dynamic> box;
    late HiveInventoryRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fridge_repo_test_');
      Hive.init(tempDir.path);
      final boxName = 'fridge_items_test_${DateTime.now().microsecondsSinceEpoch}';
      box = await Hive.openBox<dynamic>(boxName);
      repository = HiveInventoryRepository(box: box);
    });

    tearDown(() async {
      await box.close();
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads empty list from empty box', () async {
      final items = await repository.loadItems();
      expect(items, isEmpty);
    });

    test('saves and loads items correctly', () async {
      final source = [
        FridgeItem(
          id: '1',
          name: 'Milk',
          barcode: '599123',
          quantity: 2,
          expirationDate: DateTime(2026, 2, 15),
          location: StorageLocation.fridge,
        ),
      ];

      await repository.saveItems(source);
      final loaded = await repository.loadItems();

      expect(loaded.length, 1);
      expect(loaded.first.id, '1');
      expect(loaded.first.name, 'Milk');
      expect(loaded.first.barcode, '599123');
      expect(loaded.first.expirationDate, DateTime(2026, 2, 15));
      expect(loaded.first.location, StorageLocation.fridge);
    });

    test('saveItems replaces previous values', () async {
      await repository.saveItems([
        FridgeItem(
          id: 'old',
          name: 'Old item',
          barcode: null,
          quantity: 1,
          expirationDate: DateTime(2026, 2, 1),
          location: StorageLocation.pantry,
        ),
      ]);

      await repository.saveItems([
        FridgeItem(
          id: 'new',
          name: 'New item',
          barcode: null,
          quantity: 3,
          expirationDate: DateTime(2026, 2, 20),
          location: StorageLocation.freezer,
        ),
      ]);

      final loaded = await repository.loadItems();
      expect(loaded.length, 1);
      expect(loaded.single.id, 'new');
      expect(loaded.single.name, 'New item');
    });
  });
}
