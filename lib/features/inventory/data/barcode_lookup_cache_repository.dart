import 'package:hive/hive.dart';

import 'barcode_lookup_models.dart';

class BarcodeLookupCacheEntry {
  const BarcodeLookupCacheEntry({
    required this.status,
    required this.updatedAtEpochMs,
    this.productName,
    this.provider,
  });

  final BarcodeLookupStatus status;
  final String? productName;
  final BarcodeLookupProvider? provider;
  final int updatedAtEpochMs;
}

class BarcodeLookupCacheRepository {
  BarcodeLookupCacheRepository({Box<dynamic>? box})
    : _box = box ?? Hive.box('app_settings');

  static const _cacheKey = 'barcode_lookup_cache_v1';
  final Box<dynamic> _box;

  BarcodeLookupCacheEntry? get(String barcode) {
    final cache = _readCacheMap();
    final row = cache[barcode];
    if (row is! Map<String, dynamic>) {
      return null;
    }

    final statusRaw = row['status'];
    final updatedAt = row['updatedAtEpochMs'];
    if (statusRaw is! String || updatedAt is! int) {
      return null;
    }

    final status = _statusFromId(statusRaw);
    if (status == null) {
      return null;
    }

    final provider = row['providerId'] is String
        ? barcodeProviderFromId(row['providerId'] as String)
        : null;
    return BarcodeLookupCacheEntry(
      status: status,
      productName: row['productName'] as String?,
      provider: provider,
      updatedAtEpochMs: updatedAt,
    );
  }

  Future<void> putFound({
    required String barcode,
    required String productName,
    required BarcodeLookupProvider provider,
  }) async {
    final cache = _readCacheMap();
    cache[barcode] = {
      'status': _statusId(BarcodeLookupStatus.found),
      'productName': productName,
      'providerId': provider.id,
      'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
    };
    await _box.put(_cacheKey, cache);
  }

  Future<void> putNotFound({required String barcode}) async {
    final cache = _readCacheMap();
    cache[barcode] = {
      'status': _statusId(BarcodeLookupStatus.notFound),
      'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
    };
    await _box.put(_cacheKey, cache);
  }

  Future<void> clear() async {
    await _box.put(_cacheKey, <String, dynamic>{});
  }

  Map<String, dynamic> _readCacheMap() {
    final raw = _box.get(_cacheKey);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  String _statusId(BarcodeLookupStatus status) => switch (status) {
    BarcodeLookupStatus.found => 'found',
    BarcodeLookupStatus.notFound => 'not_found',
    BarcodeLookupStatus.failed => 'failed',
  };

  BarcodeLookupStatus? _statusFromId(String value) => switch (value) {
    'found' => BarcodeLookupStatus.found,
    'not_found' => BarcodeLookupStatus.notFound,
    'failed' => BarcodeLookupStatus.failed,
    _ => null,
  };
}
