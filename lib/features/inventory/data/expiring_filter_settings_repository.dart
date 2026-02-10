import 'package:hive/hive.dart';

class ExpiringFilterSettingsRepository {
  ExpiringFilterSettingsRepository({Box<dynamic>? box})
    : _box = box ?? Hive.box('app_settings');

  static const _key = 'expiring_filter_days_v1';
  final Box<dynamic> _box;

  Future<int?> loadDays() async {
    final raw = _box.get(_key);
    if (raw is int && raw >= 0) {
      return raw;
    }
    return null;
  }

  Future<void> saveDays(int? days) async {
    if (days == null) {
      await _box.delete(_key);
      return;
    }
    await _box.put(_key, days);
  }
}
