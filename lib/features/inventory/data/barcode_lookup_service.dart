import 'barcode_lookup_cache_repository.dart';
import 'barcode_lookup_models.dart';
import 'barcode_lookup_provider_client.dart';
import 'barcode_lookup_settings_repository.dart';

class BarcodeLookupService {
  BarcodeLookupService({
    required BarcodeLookupSettingsRepository settingsRepository,
    required BarcodeLookupCacheRepository cacheRepository,
    BarcodeLookupProviderClient? providerClient,
  }) : _settingsRepository = settingsRepository,
       _cacheRepository = cacheRepository,
       _providerClient = providerClient ?? BarcodeLookupProviderClient();

  final BarcodeLookupSettingsRepository _settingsRepository;
  final BarcodeLookupCacheRepository _cacheRepository;
  final BarcodeLookupProviderClient _providerClient;

  Future<BarcodeLookupResult> lookupProduct(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) {
      return BarcodeLookupResult.notFound();
    }

    final cached = _cacheRepository.get(cleanBarcode);
    if (cached != null && cached.status == BarcodeLookupStatus.found) {
      return _fromCacheEntry(cached);
    }

    final settings = await _settingsRepository.loadSettings();
    final providers = settings.orderedProviders
        .where(settings.enabledProviders.contains)
        .toList(growable: false);

    if (providers.isEmpty) {
      return BarcodeLookupResult.notFound();
    }

    var anyNotFound = false;
    for (final provider in providers) {
      final result = await _providerClient.lookupProduct(
        provider: provider,
        barcode: cleanBarcode,
      );
      switch (result.status) {
        case BarcodeLookupStatus.found:
          await _cacheRepository.putFound(
            barcode: cleanBarcode,
            productName: result.productName!,
            provider: provider,
          );
          return result;
        case BarcodeLookupStatus.notFound:
          anyNotFound = true;
          break;
        case BarcodeLookupStatus.failed:
          break;
      }
    }

    if (anyNotFound) {
      return BarcodeLookupResult.notFound();
    }
    return BarcodeLookupResult.failed();
  }

  BarcodeLookupResult _fromCacheEntry(BarcodeLookupCacheEntry entry) {
    switch (entry.status) {
      case BarcodeLookupStatus.found:
        if (entry.productName == null || entry.provider == null) {
          return BarcodeLookupResult.failed();
        }
        return BarcodeLookupResult.found(
          productName: entry.productName!,
          provider: entry.provider!,
          fromCache: true,
        );
      case BarcodeLookupStatus.notFound:
        return BarcodeLookupResult.notFound(fromCache: true);
      case BarcodeLookupStatus.failed:
        return BarcodeLookupResult.failed();
    }
  }
}
