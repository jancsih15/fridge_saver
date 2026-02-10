import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_cache_repository.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_models.dart';
import 'package:hive/hive.dart';

void main() {
  group('BarcodeLookupCacheRepository', () {
    late Directory tempDir;
    late Box<dynamic> box;
    late BarcodeLookupCacheRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('barcode_cache_test_');
      Hive.init(tempDir.path);
      final boxName =
          'app_settings_test_${DateTime.now().microsecondsSinceEpoch}';
      box = await Hive.openBox<dynamic>(boxName);
      repository = BarcodeLookupCacheRepository(box: box);
    });

    tearDown(() async {
      if (box.isOpen) {
        await box.deleteFromDisk();
      }
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('stores and reads found entry', () async {
      await repository.putFound(
        barcode: '111',
        productName: 'Yogurt',
        provider: BarcodeLookupProvider.openFoodFacts,
      );

      final row = repository.get('111');
      expect(row, isNotNull);
      expect(row!.status, BarcodeLookupStatus.found);
      expect(row.productName, 'Yogurt');
      expect(row.provider, BarcodeLookupProvider.openFoodFacts);
    });

    test('stores and reads notFound entry', () async {
      await repository.putNotFound(barcode: '222');

      final row = repository.get('222');
      expect(row, isNotNull);
      expect(row!.status, BarcodeLookupStatus.notFound);
      expect(row.productName, isNull);
      expect(row.provider, isNull);
    });

    test('clear removes cached entries', () async {
      await repository.putNotFound(barcode: '333');
      expect(repository.get('333'), isNotNull);

      await repository.clear();
      expect(repository.get('333'), isNull);
    });
  });
}
