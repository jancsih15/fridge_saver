import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/barcode_lookup_models.dart';

void main() {
  test('provider metadata and id roundtrip works', () {
    for (final provider in BarcodeLookupProvider.values) {
      expect(provider.id, isNotEmpty);
      expect(provider.label, isNotEmpty);
      expect(provider.host, contains('.'));
      expect(barcodeProviderFromId(provider.id), provider);
    }
  });

  test('provider from id returns null for unknown value', () {
    expect(barcodeProviderFromId('unknown_provider'), isNull);
  });

  test('lookup result factories populate expected fields', () {
    final found = BarcodeLookupResult.found(
      productName: 'Milk',
      provider: BarcodeLookupProvider.openFoodFacts,
      fromCache: true,
    );
    expect(found.status, BarcodeLookupStatus.found);
    expect(found.productName, 'Milk');
    expect(found.provider, BarcodeLookupProvider.openFoodFacts);
    expect(found.fromCache, isTrue);

    final notFound = BarcodeLookupResult.notFound(fromCache: true);
    expect(notFound.status, BarcodeLookupStatus.notFound);
    expect(notFound.productName, isNull);
    expect(notFound.fromCache, isTrue);

    final failed = BarcodeLookupResult.failed();
    expect(failed.status, BarcodeLookupStatus.failed);
    expect(failed.productName, isNull);
  });
}
