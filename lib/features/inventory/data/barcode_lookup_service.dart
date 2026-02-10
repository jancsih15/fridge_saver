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

    final manualName = _cacheRepository.getManualName(cleanBarcode);
    if (manualName != null) {
      return BarcodeLookupResult.found(
        productName: manualName,
        fromCache: true,
      );
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
        if (entry.productName == null) {
          return BarcodeLookupResult.failed();
        }
        return BarcodeLookupResult.found(
          productName: entry.productName!,
          provider: entry.provider,
          fromCache: true,
        );
      case BarcodeLookupStatus.notFound:
        return BarcodeLookupResult.notFound(fromCache: true);
      case BarcodeLookupStatus.failed:
        return BarcodeLookupResult.failed();
    }
  }

  Future<void> rememberNameForBarcode({
    required String barcode,
    required String productName,
  }) async {
    final cleanBarcode = barcode.trim();
    final cleanName = productName.trim();
    if (cleanBarcode.isEmpty || cleanName.isEmpty) {
      return;
    }
    await _cacheRepository.putManualName(
      barcode: cleanBarcode,
      productName: cleanName,
    );
    await _cacheRepository.putFound(
      barcode: cleanBarcode,
      productName: cleanName,
      provider: null,
    );
  }
}
