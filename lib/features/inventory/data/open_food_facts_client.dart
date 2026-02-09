import 'dart:convert';

import 'package:http/http.dart' as http;

enum OpenFoodFactsLookupStatus { found, notFound, failed }

class OpenFoodFactsLookupResult {
  const OpenFoodFactsLookupResult._({required this.status, this.productName});

  final OpenFoodFactsLookupStatus status;
  final String? productName;

  factory OpenFoodFactsLookupResult.found(String productName) {
    return OpenFoodFactsLookupResult._(
      status: OpenFoodFactsLookupStatus.found,
      productName: productName,
    );
  }

  factory OpenFoodFactsLookupResult.notFound() {
    return const OpenFoodFactsLookupResult._(
      status: OpenFoodFactsLookupStatus.notFound,
    );
  }

  factory OpenFoodFactsLookupResult.failed() {
    return const OpenFoodFactsLookupResult._(
      status: OpenFoodFactsLookupStatus.failed,
    );
  }
}

class OpenFoodFactsClient {
  OpenFoodFactsClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<OpenFoodFactsLookupResult> lookupProduct(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) {
      return OpenFoodFactsLookupResult.notFound();
    }

    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$cleanBarcode',
      {'fields': 'product_name,status'},
    );

    try {
      final response = await _httpClient.get(uri);

      if (response.statusCode == 404) {
        return OpenFoodFactsLookupResult.notFound();
      }

      if (response.statusCode != 200) {
        return OpenFoodFactsLookupResult.failed();
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return OpenFoodFactsLookupResult.failed();
      }

      final status = data['status'];
      if (status != 1) {
        return OpenFoodFactsLookupResult.notFound();
      }

      final product = data['product'];
      if (product is! Map<String, dynamic>) {
        return OpenFoodFactsLookupResult.notFound();
      }

      final name = (product['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        return OpenFoodFactsLookupResult.notFound();
      }

      return OpenFoodFactsLookupResult.found(name);
    } catch (_) {
      return OpenFoodFactsLookupResult.failed();
    }
  }

  Future<String?> fetchProductName(String barcode) async {
    final result = await lookupProduct(barcode);
    return result.productName;
  }
}
