import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_cache_repository.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_models.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_provider_client.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_service.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_settings_repository.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BarcodeLookupService', () {
    late Directory tempDir;
    late Box<dynamic> box;
    late BarcodeLookupSettingsRepository settingsRepo;
    late BarcodeLookupCacheRepository cacheRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('barcode_lookup_test_');
      Hive.init(tempDir.path);
      final boxName =
          'app_settings_test_${DateTime.now().microsecondsSinceEpoch}';
      box = await Hive.openBox<dynamic>(boxName);
      settingsRepo = BarcodeLookupSettingsRepository(box: box);
      cacheRepo = BarcodeLookupCacheRepository(box: box);
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

    test(
      'falls back to next enabled provider when first is not found',
      () async {
        await settingsRepo.saveSettings(
          const BarcodeLookupSettings(
            orderedProviders: [
              BarcodeLookupProvider.openFoodFacts,
              BarcodeLookupProvider.openBeautyFacts,
            ],
            enabledProviders: {
              BarcodeLookupProvider.openFoodFacts,
              BarcodeLookupProvider.openBeautyFacts,
            },
          ),
        );

        final providerClient = BarcodeLookupProviderClient(
          httpClient: MockClient((request) async {
            if (request.url.host == BarcodeLookupProvider.openFoodFacts.host) {
              return http.Response('{"status":0}', 200);
            }
            if (request.url.host ==
                BarcodeLookupProvider.openBeautyFacts.host) {
              return http.Response(
                '{"status":1,"product":{"product_name":"Beauty Soap"}}',
                200,
              );
            }
            return http.Response('{"status":0}', 200);
          }),
        );

        final service = BarcodeLookupService(
          settingsRepository: settingsRepo,
          cacheRepository: cacheRepo,
          providerClient: providerClient,
        );

        final result = await service.lookupProduct('123');
        expect(result.status, BarcodeLookupStatus.found);
        expect(result.productName, 'Beauty Soap');
        expect(result.provider, BarcodeLookupProvider.openBeautyFacts);
        expect(result.fromCache, isFalse);
      },
    );

    test('returns cached result without network call', () async {
      var callCount = 0;
      final providerClient = BarcodeLookupProviderClient(
        httpClient: MockClient((request) async {
          callCount += 1;
          return http.Response(
            '{"status":1,"product":{"product_name":"ShouldNotBeCalled"}}',
            200,
          );
        }),
      );

      await cacheRepo.putFound(
        barcode: '999',
        productName: 'Cached Product',
        provider: BarcodeLookupProvider.openFoodFacts,
      );

      final service = BarcodeLookupService(
        settingsRepository: settingsRepo,
        cacheRepository: cacheRepo,
        providerClient: providerClient,
      );

      final result = await service.lookupProduct('999');
      expect(result.status, BarcodeLookupStatus.found);
      expect(result.productName, 'Cached Product');
      expect(result.fromCache, isTrue);
      expect(callCount, 0);
    });

    test('ignores stale cached notFound and still queries providers', () async {
      await cacheRepo.putNotFound(barcode: '321');
      await settingsRepo.saveSettings(
        const BarcodeLookupSettings(
          orderedProviders: [BarcodeLookupProvider.openFoodFacts],
          enabledProviders: {BarcodeLookupProvider.openFoodFacts},
        ),
      );

      var callCount = 0;
      final service = BarcodeLookupService(
        settingsRepository: settingsRepo,
        cacheRepository: cacheRepo,
        providerClient: BarcodeLookupProviderClient(
          httpClient: MockClient((_) async {
            callCount += 1;
            return http.Response(
              '{"status":1,"product":{"product_name":"Recovered Product"}}',
              200,
            );
          }),
        ),
      );

      final result = await service.lookupProduct('321');
      expect(result.status, BarcodeLookupStatus.found);
      expect(result.productName, 'Recovered Product');
      expect(result.fromCache, isFalse);
      expect(callCount, 1);
    });

    test('returns notFound for empty barcode', () async {
      final service = BarcodeLookupService(
        settingsRepository: settingsRepo,
        cacheRepository: cacheRepo,
        providerClient: BarcodeLookupProviderClient(
          httpClient: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

      final result = await service.lookupProduct('   ');
      expect(result.status, BarcodeLookupStatus.notFound);
    });

    test('returns failed when all providers fail', () async {
      await settingsRepo.saveSettings(
        const BarcodeLookupSettings(
          orderedProviders: [BarcodeLookupProvider.openFoodFacts],
          enabledProviders: {BarcodeLookupProvider.openFoodFacts},
        ),
      );

      final service = BarcodeLookupService(
        settingsRepository: settingsRepo,
        cacheRepository: cacheRepo,
        providerClient: BarcodeLookupProviderClient(
          httpClient: MockClient((_) async => http.Response('', 500)),
        ),
      );

      final result = await service.lookupProduct('123');
      expect(result.status, BarcodeLookupStatus.failed);
    });

    test('does not reuse cached notFound result on next call', () async {
      await settingsRepo.saveSettings(
        const BarcodeLookupSettings(
          orderedProviders: [BarcodeLookupProvider.openFoodFacts],
          enabledProviders: {BarcodeLookupProvider.openFoodFacts},
        ),
      );

      var callCount = 0;
      final service = BarcodeLookupService(
        settingsRepository: settingsRepo,
        cacheRepository: cacheRepo,
        providerClient: BarcodeLookupProviderClient(
          httpClient: MockClient((_) async {
            callCount += 1;
            return http.Response('{"status":0}', 200);
          }),
        ),
      );

      final first = await service.lookupProduct('777');
      expect(first.status, BarcodeLookupStatus.notFound);
      expect(first.fromCache, isFalse);
      expect(callCount, 1);

      final second = await service.lookupProduct('777');
      expect(second.status, BarcodeLookupStatus.notFound);
      expect(second.fromCache, isFalse);
      expect(callCount, 2);
    });
  });
}
