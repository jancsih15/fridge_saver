import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/inventory_repository.dart';
import '../domain/fridge_item.dart';

typedef NowProvider = DateTime Function();

class DeletedInventoryItem {
  DeletedInventoryItem({
    required this.item,
    required this.index,
  });

  final FridgeItem item;
  final int index;
}

class InventoryController extends ChangeNotifier {
  InventoryController({
    required InventoryRepository repository,
    NowProvider? now,
    Uuid? uuid,
  })  : _repository = repository,
        _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid();

  final InventoryRepository _repository;
  final NowProvider _now;
  final Uuid _uuid;

  final List<FridgeItem> _items = [];
  bool _expiringSoonOnly = false;

  List<FridgeItem> get allItems => List.unmodifiable(_items);
  bool get expiringSoonOnly => _expiringSoonOnly;

  List<FridgeItem> get visibleItems {
    final source = _expiringSoonOnly
        ? _items.where(_isExpiringSoon).toList(growable: false)
        : _items;
    final sorted = List<FridgeItem>.from(source);
    sorted.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
    return sorted;
  }

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _repository.loadItems());
    notifyListeners();
  }

  Future<void> addItem({
    required String name,
    required int quantity,
    required DateTime expirationDate,
    required StorageLocation location,
    String? barcode,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    _items.add(
      FridgeItem(
        id: _uuid.v4(),
        name: trimmedName,
        barcode: barcode?.trim().isEmpty ?? true ? null : barcode?.trim(),
        quantity: quantity,
        expirationDate: DateTime(
          expirationDate.year,
          expirationDate.month,
          expirationDate.day,
        ),
        location: location,
      ),
    );

    await _repository.saveItems(_items);
    notifyListeners();
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required int quantity,
    required DateTime expirationDate,
    required StorageLocation location,
    String? barcode,
  }) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    _items[index] = FridgeItem(
      id: id,
      name: trimmedName,
      barcode: barcode?.trim().isEmpty ?? true ? null : barcode?.trim(),
      quantity: quantity,
      expirationDate: DateTime(
        expirationDate.year,
        expirationDate.month,
        expirationDate.day,
      ),
      location: location,
    );

    await _repository.saveItems(_items);
    notifyListeners();
  }

  Future<DeletedInventoryItem?> deleteItem(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return null;
    }

    final removed = _items.removeAt(index);

    await _repository.saveItems(_items);
    notifyListeners();
    return DeletedInventoryItem(item: removed, index: index);
  }

  Future<void> restoreDeletedItem(DeletedInventoryItem deleted) async {
    if (_items.any((item) => item.id == deleted.item.id)) {
      return;
    }

    var targetIndex = deleted.index;
    if (targetIndex < 0) {
      targetIndex = 0;
    } else if (targetIndex > _items.length) {
      targetIndex = _items.length;
    }

    _items.insert(targetIndex, deleted.item);
    await _repository.saveItems(_items);
    notifyListeners();
  }

  void setExpiringSoonOnly(bool value) {
    _expiringSoonOnly = value;
    notifyListeners();
  }

  bool _isExpiringSoon(FridgeItem item) {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = item.expirationDate.difference(today).inDays;
    return diffDays >= 0 && diffDays <= 3;
  }
}
