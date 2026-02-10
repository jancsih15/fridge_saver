import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_models.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_provider_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BarcodeLookupProviderClient', () {
    test('returns notFound on empty barcode', () async {
      final client = BarcodeLookupProviderClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      final result = await client.lookupProduct(
        provider: BarcodeLookupProvider.openFoodFacts,
        barcode: '   ',
      );
      expect(result.status, BarcodeLookupStatus.notFound);
    });

    test('returns notFound on 404', () async {
      final client = BarcodeLookupProviderClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      final result = await client.lookupProduct(
        provider: BarcodeLookupProvider.openFoodFacts,
        barcode: '123',
      );
      expect(result.status, BarcodeLookupStatus.notFound);
    });

    test('returns failed on non-200 non-404', () async {
      final client = BarcodeLookupProviderClient(
        httpClient: MockClient((_) async => http.Response('', 500)),
      );
      final result = await client.lookupProduct(
        provider: BarcodeLookupProvider.openFoodFacts,
        barcode: '123',
      );
      expect(result.status, BarcodeLookupStatus.failed);
    });

    test('returns failed on invalid json', () async {
      final client = BarcodeLookupProviderClient(
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );
      final result = await client.lookupProduct(
        provider: BarcodeLookupProvider.openFoodFacts,
        barcode: '123',
      );
      expect(result.status, BarcodeLookupStatus.failed);
    });

    test('returns notFound when status is not 1', () async {
      final client = BarcodeLookupProviderClient(
        httpClient: MockClient((_) async => http.Response('{"status":0}', 200)),
      );
      final result = await client.lookupProduct(
        provider: BarcodeLookupProvider.openFoodFacts,
        barcode: '123',
      );
      expect(result.status, BarcodeLookupStatus.notFound);
    });

    test(
      'returns found with provider when valid product name exists',
      () async {
        final client = BarcodeLookupProviderClient(
          httpClient: MockClient(
            (_) async => http.Response(
              '{"status":1,"product":{"product_name":"Hungarian Water"}}',
              200,
            ),
          ),
        );
        final result = await client.lookupProduct(
          provider: BarcodeLookupProvider.openFoodFacts,
          barcode: '123',
        );
        expect(result.status, BarcodeLookupStatus.found);
        expect(result.productName, 'Hungarian Water');
        expect(result.provider, BarcodeLookupProvider.openFoodFacts);
      },
    );
  });
}
