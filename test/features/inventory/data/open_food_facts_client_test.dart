import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fridge_saver/features/inventory/data/open_food_facts_client.dart';

void main() {
  group('OpenFoodFactsClient', () {
    test('returns found with product_name when API has a match', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v2/product/5449000000996');
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {'product_name': 'Coca-Cola'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final result = await api.lookupProduct('5449000000996');

      expect(result.status, OpenFoodFactsLookupStatus.found);
      expect(result.productName, 'Coca-Cola');
    });

    test('returns notFound when product is not found', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final result = await api.lookupProduct('0000');

      expect(result.status, OpenFoodFactsLookupStatus.notFound);
      expect(result.productName, isNull);
    });

    test('returns notFound on 404 response', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final result = await api.lookupProduct('9999');

      expect(result.status, OpenFoodFactsLookupStatus.notFound);
      expect(result.productName, isNull);
    });

    test('returns failed on server errors', () async {
      final client = MockClient((request) async {
        return http.Response('error', 500);
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final result = await api.lookupProduct('1234');

      expect(result.status, OpenFoodFactsLookupStatus.failed);
      expect(result.productName, isNull);
    });
  });
}
