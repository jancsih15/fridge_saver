import 'package:hive/hive.dart';

import '../domain/fridge_item.dart';

abstract class InventoryRepository {
  Future<List<FridgeItem>> loadItems();
  Future<void> saveItems(List<FridgeItem> items);
}

class HiveInventoryRepository implements InventoryRepository {
  HiveInventoryRepository({Box<dynamic>? box}) : _box = box ?? Hive.box('fridge_items');

  final Box<dynamic> _box;

  @override
  Future<List<FridgeItem>> loadItems() async {
    return _box.values
        .map((raw) => FridgeItem.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList(growable: false);
  }

  @override
  Future<void> saveItems(List<FridgeItem> items) async {
    await _box.clear();
    await _box.addAll(items.map((item) => item.toMap()));
  }
}
