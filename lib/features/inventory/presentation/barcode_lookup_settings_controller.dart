import 'package:flutter/foundation.dart';

import '../data/barcode_lookup_cache_repository.dart';
import '../data/barcode_lookup_models.dart';
import '../data/barcode_lookup_settings_repository.dart';

class BarcodeLookupSettingsController extends ChangeNotifier {
  BarcodeLookupSettingsController({
    required BarcodeLookupSettingsRepository settingsRepository,
    required BarcodeLookupCacheRepository cacheRepository,
  }) : _settingsRepository = settingsRepository,
       _cacheRepository = cacheRepository;

  final BarcodeLookupSettingsRepository _settingsRepository;
  final BarcodeLookupCacheRepository _cacheRepository;

  List<BarcodeLookupProvider> _order = List.from(BarcodeLookupProvider.values);
  Set<BarcodeLookupProvider> _enabled = Set.from(BarcodeLookupProvider.values);
  bool _loaded = false;

  List<BarcodeLookupProvider> get order => List.unmodifiable(_order);
  bool get loaded => _loaded;

  bool isEnabled(BarcodeLookupProvider provider) => _enabled.contains(provider);

  Future<void> load() async {
    final settings = await _settingsRepository.loadSettings();
    _order = List<BarcodeLookupProvider>.from(settings.orderedProviders);
    _enabled = Set<BarcodeLookupProvider>.from(settings.enabledProviders);
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleProvider(
    BarcodeLookupProvider provider,
    bool value,
  ) async {
    if (value) {
      _enabled.add(provider);
    } else {
      if (_enabled.length == 1 && _enabled.contains(provider)) {
        return;
      }
      _enabled.remove(provider);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> reorderProvider(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = _order.removeAt(oldIndex);
    _order.insert(newIndex, moved);
    await _persist();
    notifyListeners();
  }

  Future<void> restoreDefaults() async {
    _order = List<BarcodeLookupProvider>.from(BarcodeLookupProvider.values);
    _enabled = Set<BarcodeLookupProvider>.from(BarcodeLookupProvider.values);
    await _persist();
    notifyListeners();
  }

  Future<void> clearCache() async {
    await _cacheRepository.clear();
  }

  Future<void> _persist() async {
    await _settingsRepository.saveSettings(
      BarcodeLookupSettings(
        orderedProviders: _order,
        enabledProviders: _enabled,
      ),
    );
  }
}
