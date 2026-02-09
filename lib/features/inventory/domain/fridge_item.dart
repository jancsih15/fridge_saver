enum StorageLocation { fridge, freezer, pantry }

class FridgeItem {
  FridgeItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.expirationDate,
    required this.location,
    this.barcode,
  });

  final String id;
  final String name;
  final String? barcode;
  final int quantity;
  final DateTime expirationDate;
  final StorageLocation location;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'quantity': quantity,
      'expirationDate': expirationDate.toIso8601String(),
      'location': location.name,
    };
  }

  factory FridgeItem.fromMap(Map<String, dynamic> map) {
    return FridgeItem(
      id: map['id'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      quantity: map['quantity'] as int,
      expirationDate: DateTime.parse(map['expirationDate'] as String),
      location: StorageLocation.values.firstWhere(
        (value) => value.name == map['location'],
      ),
    );
  }
}
