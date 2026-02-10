import 'dart:convert';

import 'package:http/http.dart' as http;

import 'barcode_lookup_models.dart';

class BarcodeLookupProviderClient {
  BarcodeLookupProviderClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<BarcodeLookupResult> lookupProduct({
    required BarcodeLookupProvider provider,
    required String barcode,
  }) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) {
      return BarcodeLookupResult.notFound();
    }

    final uri = Uri.https(provider.host, '/api/v2/product/$cleanBarcode', {
      'fields': 'product_name,status',
    });

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode == 404) {
        return BarcodeLookupResult.notFound();
      }
      if (response.statusCode != 200) {
        return BarcodeLookupResult.failed();
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return BarcodeLookupResult.failed();
      }

      final status = data['status'];
      if (status != 1) {
        return BarcodeLookupResult.notFound();
      }

      final product = data['product'];
      if (product is! Map<String, dynamic>) {
        return BarcodeLookupResult.notFound();
      }

      final name = (product['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        return BarcodeLookupResult.notFound();
      }

      return BarcodeLookupResult.found(productName: name, provider: provider);
    } catch (_) {
      return BarcodeLookupResult.failed();
    }
  }
}
