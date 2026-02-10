enum BarcodeLookupProvider {
  openFoodFacts,
  openBeautyFacts,
  openProductsFacts,
  openPetFoodFacts,
}

extension BarcodeLookupProviderInfo on BarcodeLookupProvider {
  String get id => switch (this) {
    BarcodeLookupProvider.openFoodFacts => 'open_food_facts',
    BarcodeLookupProvider.openBeautyFacts => 'open_beauty_facts',
    BarcodeLookupProvider.openProductsFacts => 'open_products_facts',
    BarcodeLookupProvider.openPetFoodFacts => 'open_pet_food_facts',
  };

  String get label => switch (this) {
    BarcodeLookupProvider.openFoodFacts => 'Open Food Facts',
    BarcodeLookupProvider.openBeautyFacts => 'Open Beauty Facts',
    BarcodeLookupProvider.openProductsFacts => 'Open Products Facts',
    BarcodeLookupProvider.openPetFoodFacts => 'Open Pet Food Facts',
  };

  String get host => switch (this) {
    BarcodeLookupProvider.openFoodFacts => 'world.openfoodfacts.org',
    BarcodeLookupProvider.openBeautyFacts => 'world.openbeautyfacts.org',
    BarcodeLookupProvider.openProductsFacts => 'world.openproductsfacts.org',
    BarcodeLookupProvider.openPetFoodFacts => 'world.openpetfoodfacts.org',
  };
}

BarcodeLookupProvider? barcodeProviderFromId(String value) {
  for (final provider in BarcodeLookupProvider.values) {
    if (provider.id == value) {
      return provider;
    }
  }
  return null;
}

enum BarcodeLookupStatus { found, notFound, failed }

class BarcodeLookupResult {
  const BarcodeLookupResult._({
    required this.status,
    this.productName,
    this.provider,
    this.fromCache = false,
  });

  final BarcodeLookupStatus status;
  final String? productName;
  final BarcodeLookupProvider? provider;
  final bool fromCache;

  factory BarcodeLookupResult.found({
    required String productName,
    BarcodeLookupProvider? provider,
    bool fromCache = false,
  }) {
    return BarcodeLookupResult._(
      status: BarcodeLookupStatus.found,
      productName: productName,
      provider: provider,
      fromCache: fromCache,
    );
  }

  factory BarcodeLookupResult.notFound({bool fromCache = false}) {
    return BarcodeLookupResult._(
      status: BarcodeLookupStatus.notFound,
      fromCache: fromCache,
    );
  }

  factory BarcodeLookupResult.failed() {
    return const BarcodeLookupResult._(status: BarcodeLookupStatus.failed);
  }
}
