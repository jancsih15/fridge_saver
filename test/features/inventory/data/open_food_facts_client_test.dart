import 'dart:io';
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

    test('returns notFound for empty barcode input', () async {
      final api = OpenFoodFactsClient(httpClient: MockClient((_) async {
        fail('HTTP should not be called for empty barcode');
      }));

      final result = await api.lookupProduct('   ');
      expect(result.status, OpenFoodFactsLookupStatus.notFound);
      expect(result.productName, isNull);
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

    test('returns failed for invalid JSON response body', () async {
      final client = MockClient((request) async {
        return http.Response('not-json', 200);
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final result = await api.lookupProduct('1234');

      expect(result.status, OpenFoodFactsLookupStatus.failed);
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

    test('returns failed when HTTP client throws', () async {
      final client = MockClient((request) async {
        throw const SocketException('network down');
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final result = await api.lookupProduct('1234');

      expect(result.status, OpenFoodFactsLookupStatus.failed);
      expect(result.productName, isNull);
    });

    test('fetchProductName returns productName when found', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {'product_name': 'Sprite'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final value = await api.fetchProductName('5449000001009');

      expect(value, 'Sprite');
    });

    test('fetchProductName returns null when not found', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'status': 0}), 200);
      });

      final api = OpenFoodFactsClient(httpClient: client);
      final value = await api.fetchProductName('0000');

      expect(value, isNull);
    });
  });
}

