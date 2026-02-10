import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/expiration_notification_scheduler.dart';
import '../data/inventory_repository.dart';
import '../domain/fridge_item.dart';

typedef NowProvider = DateTime Function();

class DeletedInventoryItem {
  DeletedInventoryItem({required this.item, required this.index});

  final FridgeItem item;
  final int index;
}

class InventoryController extends ChangeNotifier {
  InventoryController({
    required InventoryRepository repository,
    ExpirationNotificationScheduler? notificationScheduler,
    NowProvider? now,
    Uuid? uuid,
  }) : _repository = repository,
       _notificationScheduler = notificationScheduler,
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final InventoryRepository _repository;
  final ExpirationNotificationScheduler? _notificationScheduler;
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
    await _syncNotifications();
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
    final normalizedBarcode = _normalizeBarcode(barcode);
    final normalizedDate = _normalizeDate(expirationDate);
    if (trimmedName.isEmpty) {
      return;
    }

    final duplicateIndex = _items.indexWhere(
      (item) => _isSameBatch(
        item: item,
        name: trimmedName,
        barcode: normalizedBarcode,
        expirationDate: normalizedDate,
        location: location,
      ),
    );

    if (duplicateIndex != -1) {
      final existing = _items[duplicateIndex];
      _items[duplicateIndex] = FridgeItem(
        id: existing.id,
        name: existing.name,
        barcode: existing.barcode,
        quantity: existing.quantity + quantity,
        expirationDate: existing.expirationDate,
        location: existing.location,
      );
    } else {
      _items.add(
        FridgeItem(
          id: _uuid.v4(),
          name: trimmedName,
          barcode: normalizedBarcode,
          quantity: quantity,
          expirationDate: normalizedDate,
          location: location,
        ),
      );
    }

    await _repository.saveItems(_items);
    await _syncNotifications();
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
    final normalizedBarcode = _normalizeBarcode(barcode);
    final normalizedDate = _normalizeDate(expirationDate);
    if (trimmedName.isEmpty) {
      return;
    }

    final duplicateIndex = _items.indexWhere(
      (item) =>
          item.id != id &&
          _isSameBatch(
            item: item,
            name: trimmedName,
            barcode: normalizedBarcode,
            expirationDate: normalizedDate,
            location: location,
          ),
    );

    if (duplicateIndex != -1) {
      final duplicate = _items[duplicateIndex];
      _items[duplicateIndex] = FridgeItem(
        id: duplicate.id,
        name: duplicate.name,
        barcode: duplicate.barcode,
        quantity: duplicate.quantity + quantity,
        expirationDate: duplicate.expirationDate,
        location: duplicate.location,
      );
      _items.removeAt(index);
    } else {
      _items[index] = FridgeItem(
        id: id,
        name: trimmedName,
        barcode: normalizedBarcode,
        quantity: quantity,
        expirationDate: normalizedDate,
        location: location,
      );
    }

    await _repository.saveItems(_items);
    await _syncNotifications();
    notifyListeners();
  }

  Future<DeletedInventoryItem?> deleteItem(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return null;
    }

    final removed = _items.removeAt(index);

    await _repository.saveItems(_items);
    await _syncNotifications();
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
    await _syncNotifications();
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

  String? _normalizeBarcode(String? barcode) {
    final trimmed = barcode?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameBatch({
    required FridgeItem item,
    required String name,
    required String? barcode,
    required DateTime expirationDate,
    required StorageLocation location,
  }) {
    return item.name.toLowerCase() == name.toLowerCase() &&
        item.barcode == barcode &&
        item.expirationDate == expirationDate &&
        item.location == location;
  }

  Future<void> _syncNotifications() async {
    if (_notificationScheduler == null) {
      return;
    }
    try {
      await _notificationScheduler.syncItemReminders(_items);
    } catch (_) {
      // Notification backends are optional and platform-dependent.
      // Never block core inventory updates if scheduling fails.
    }
  }
}
