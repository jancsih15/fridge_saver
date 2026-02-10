import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/presentation/expiry_date_parser.dart';

void main() {
  test('parses yyyy-mm-dd format', () {
    final result = suggestExpirationDateFromText(
      'Lejarat: 2026-12-31',
      now: DateTime(2026, 1, 1),
    );

    expect(result, DateTime(2026, 12, 31));
  });

  test('parses dd.mm.yyyy format', () {
    final result = suggestExpirationDateFromText(
      'Best before 12.03.2027',
      now: DateTime(2026, 1, 1),
    );

    expect(result, DateTime(2027, 3, 12));
  });

  test('parses dd,mm,yyyy format', () {
    final result = suggestExpirationDateFromText(
      'EXP 14,07,2027',
      now: DateTime(2026, 1, 1),
    );

    expect(result, DateTime(2027, 7, 14));
  });

  test('parses mizse-like OCR lines with dot-separated date', () {
    final result = suggestExpirationDateFromText(
      '9L42920320\n14.07.2027',
      now: DateTime(2026, 1, 1),
    );

    expect(result, DateTime(2027, 7, 14));
  });

  test('parses wippy-like OCR line with time suffix', () {
    final result = suggestExpirationDateFromText(
      'SP1 19/11/2025 01:58',
      now: DateTime(2025, 1, 1),
    );

    expect(result, DateTime(2025, 11, 19));
  });

  test('parses dd/mm without year using current year', () {
    final result = suggestExpirationDateFromText(
      'EXP 05/10',
      now: DateTime(2026, 1, 1),
    );

    expect(result, DateTime(2026, 10, 5));
  });

  test('rolls dd/mm without year to next year when already past', () {
    final result = suggestExpirationDateFromText(
      'EXP 05/01',
      now: DateTime(2026, 3, 1),
    );

    expect(result, DateTime(2027, 1, 5));
  });

  test('prefers date on expiry keyword line over non-keyword earlier date', () {
    final analysis = analyzeExpirationDateText(
      'Packed: 05.03.2026\nEXP 14,07,2027',
      now: DateTime(2026, 1, 1),
    );

    expect(analysis.suggestedDate, DateTime(2027, 7, 14));
    expect(analysis.candidates, contains(DateTime(2026, 3, 5)));
    expect(analysis.candidates, contains(DateTime(2027, 7, 14)));
  });

  test('accepts far-future dates within 30-year horizon', () {
    final result = suggestExpirationDateFromText(
      'EXP 14,07,2046',
      now: DateTime(2026, 1, 1),
    );

    expect(result, DateTime(2046, 7, 14));
  });

  test('rejects dates beyond 30-year horizon', () {
    final result = suggestExpirationDateFromText(
      'EXP 14,07,2058',
      now: DateTime(2026, 1, 1),
    );

    expect(result, isNull);
  });

  test('returns null when no valid date can be parsed', () {
    final result = suggestExpirationDateFromText(
      'No date here',
      now: DateTime(2026, 1, 1),
    );

    expect(result, isNull);
  });
}
