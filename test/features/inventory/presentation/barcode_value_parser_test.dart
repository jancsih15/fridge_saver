import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/presentation/barcode_value_parser.dart';

void main() {
  group('pickFirstBarcodeValue', () {
    test('returns first numeric EAN/UPC candidate', () {
      final value = pickFirstBarcodeValue([
        '',
        '   ',
        'https://example.com/product/123',
        '5991234567890',
      ]);
      expect(value, '5991234567890');
    });

    test('returns null when only non-product values exist', () {
      final value = pickFirstBarcodeValue([
        null,
        '',
        '   ',
        'https://example.com',
        'not-a-barcode',
      ]);
      expect(value, isNull);
    });
  });
}
