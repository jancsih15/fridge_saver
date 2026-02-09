import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/presentation/barcode_value_parser.dart';

void main() {
  group('pickFirstBarcodeValue', () {
    test('returns first non-empty trimmed value', () {
      final value = pickFirstBarcodeValue(['', '   ', '  599123  ', '999']);
      expect(value, '599123');
    });

    test('returns null when no valid values exist', () {
      final value = pickFirstBarcodeValue([null, '', '   ']);
      expect(value, isNull);
    });
  });
}
