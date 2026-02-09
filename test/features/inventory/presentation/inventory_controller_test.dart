import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/inventory_repository.dart';
import 'package:fridge_saver/features/inventory/domain/fridge_item.dart';
import 'package:fridge_saver/features/inventory/presentation/inventory_controller.dart';

class _FakeInventoryRepository implements InventoryRepository {
  _FakeInventoryRepository({List<FridgeItem>? initialItems})
      : _storedItems = List<FridgeItem>.from(initialItems ?? []);

  List<FridgeItem> _storedItems;
  int saveCalls = 0;

  @override
  Future<List<FridgeItem>> loadItems() async => List<FridgeItem>.from(_storedItems);

  @override
  Future<void> saveItems(List<FridgeItem> items) async {
    saveCalls += 1;
    _storedItems = List<FridgeItem>.from(items);
  }
}

void main() {
  group('InventoryController', () {
    test('loads existing items from repository', () async {
      final item = FridgeItem(
        id: '1',
        name: 'Milk',
        barcode: null,
        quantity: 1,
        expirationDate: DateTime(2026, 2, 15),
        location: StorageLocation.fridge,
      );
      final repo = _FakeInventoryRepository(initialItems: [item]);

      final controller = InventoryController(repository: repo);
      await controller.load();

      expect(controller.allItems.length, 1);
      expect(controller.allItems.first.name, 'Milk');
      expect(controller.expiringSoonOnly, isFalse);
      expect(controller.visibleItems.length, 1);
    });

    test('adds item and persists it', () async {
      final repo = _FakeInventoryRepository();
      final controller = InventoryController(
        repository: repo,
        now: () => DateTime(2026, 2, 9),
      );

      await controller.load();
      await controller.addItem(
        name: 'Eggs',
        barcode: '  599001  ',
        quantity: 6,
        expirationDate: DateTime(2026, 2, 12, 22, 15),
        location: StorageLocation.fridge,
      );

      expect(controller.allItems.length, 1);
      expect(controller.allItems.first.name, 'Eggs');
      expect(controller.allItems.first.barcode, '599001');
      expect(controller.allItems.first.expirationDate, DateTime(2026, 2, 12));
      expect(repo.saveCalls, 1);
    });

    test('updates item and persists changes', () async {
      final repo = _FakeInventoryRepository(initialItems: [
        FridgeItem(
          id: '1',
          name: 'Milk',
          barcode: null,
          quantity: 1,
          expirationDate: DateTime(2026, 2, 15),
          location: StorageLocation.fridge,
        ),
      ]);

      final controller = InventoryController(repository: repo);
      await controller.load();

      await controller.updateItem(
        id: '1',
        name: 'Oat Milk',
        barcode: '599999',
        quantity: 2,
        expirationDate: DateTime(2026, 2, 18),
        location: StorageLocation.pantry,
      );

      expect(controller.allItems.single.name, 'Oat Milk');
      expect(controller.allItems.single.barcode, '599999');
      expect(controller.allItems.single.quantity, 2);
      expect(controller.allItems.single.expirationDate, DateTime(2026, 2, 18));
      expect(controller.allItems.single.location, StorageLocation.pantry);
      expect(repo.saveCalls, 1);
    });

    test('deletes item by id and persists', () async {
      final repo = _FakeInventoryRepository(initialItems: [
        FridgeItem(
          id: '1',
          name: 'Milk',
          barcode: null,
          quantity: 1,
          expirationDate: DateTime(2026, 2, 15),
          location: StorageLocation.fridge,
        ),
      ]);

      final controller = InventoryController(repository: repo);
      await controller.load();

      final deleted = await controller.deleteItem('1');

      expect(controller.allItems, isEmpty);
      expect(deleted, isNotNull);
      expect(deleted!.item.id, '1');
      expect(deleted.index, 0);
      expect(repo.saveCalls, 1);
    });

    test('restores deleted item and persists', () async {
      final repo = _FakeInventoryRepository(initialItems: [
        FridgeItem(
          id: '1',
          name: 'Milk',
          barcode: null,
          quantity: 1,
          expirationDate: DateTime(2026, 2, 15),
          location: StorageLocation.fridge,
        ),
        FridgeItem(
          id: '2',
          name: 'Eggs',
          barcode: null,
          quantity: 6,
          expirationDate: DateTime(2026, 2, 16),
          location: StorageLocation.fridge,
        ),
      ]);

      final controller = InventoryController(repository: repo);
      await controller.load();

      final deleted = await controller.deleteItem('1');
      expect(controller.allItems.map((e) => e.id), ['2']);

      await controller.restoreDeletedItem(deleted!);

      expect(controller.allItems.map((e) => e.id), ['1', '2']);
      expect(repo.saveCalls, 2);
    });

    test('restore clamps out-of-range index to end of list', () async {
      final repo = _FakeInventoryRepository(initialItems: [
        FridgeItem(
          id: '2',
          name: 'Eggs',
          barcode: null,
          quantity: 6,
          expirationDate: DateTime(2026, 2, 16),
          location: StorageLocation.fridge,
        ),
      ]);

      final controller = InventoryController(repository: repo);
      await controller.load();

      await controller.restoreDeletedItem(
        DeletedInventoryItem(
          item: FridgeItem(
            id: '1',
            name: 'Milk',
            barcode: null,
            quantity: 1,
            expirationDate: DateTime(2026, 2, 15),
            location: StorageLocation.fridge,
          ),
          index: 999,
        ),
      );

      expect(controller.allItems.map((e) => e.id), ['2', '1']);
    });

    test('filters expiring soon items within 3 days', () async {
      final now = DateTime(2026, 2, 9);
      final repo = _FakeInventoryRepository(initialItems: [
        FridgeItem(
          id: '1',
          name: 'Yogurt',
          barcode: null,
          quantity: 1,
          expirationDate: DateTime(2026, 2, 11),
          location: StorageLocation.fridge,
        ),
        FridgeItem(
          id: '2',
          name: 'Rice',
          barcode: null,
          quantity: 1,
          expirationDate: DateTime(2026, 2, 20),
          location: StorageLocation.pantry,
        ),
      ]);

      final controller = InventoryController(repository: repo, now: () => now);
      await controller.load();
      controller.setExpiringSoonOnly(true);

      expect(controller.visibleItems.length, 1);
      expect(controller.visibleItems.first.name, 'Yogurt');
    });
  });
}
