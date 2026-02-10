import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_saver/features/inventory/data/ai_expiry_date_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('returns disabled when API key is missing', () async {
    final client = AiExpiryDateClient(
      apiKey: '',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );

    final result = await client.suggestDateFromOcrText('EXP 14.07.2027');
    expect(result.status, AiExpiryDateStatus.disabled);
    expect(result.date, isNull);
  });

  test('parses top-level output_text date', () async {
    final client = AiExpiryDateClient(
      apiKey: 'test-key',
      httpClient: MockClient(
        (_) async => http.Response('{"output_text":"2027-07-14"}', 200),
      ),
    );

    final result = await client.suggestDateFromOcrText('EXP 14.07.2027');
    expect(result.status, AiExpiryDateStatus.found);
    expect(result.date, DateTime(2027, 7, 14));
    expect(result.source, AiExpiryDateSource.text);
  });

  test('parses nested output content date', () async {
    final client = AiExpiryDateClient(
      apiKey: 'test-key',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"output":[{"content":[{"type":"output_text","text":"2025-11-19"}]}]}',
          200,
        ),
      ),
    );

    final result = await client.suggestDateFromOcrText('SP1 19/11/2025 01:58');
    expect(result.status, AiExpiryDateStatus.found);
    expect(result.date, DateTime(2025, 11, 19));
    expect(result.source, AiExpiryDateSource.text);
  });

  test('returns noDate when model answers NONE', () async {
    final client = AiExpiryDateClient(
      apiKey: 'test-key',
      httpClient: MockClient(
        (_) async => http.Response('{"output_text":"NONE"}', 200),
      ),
    );

    final result = await client.suggestDateFromOcrText('random text');
    expect(result.status, AiExpiryDateStatus.noDate);
    expect(result.date, isNull);
  });

  test('returns failed on non-2xx response', () async {
    final client = AiExpiryDateClient(
      apiKey: 'test-key',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"bad"}', 500),
      ),
    );

    final result = await client.suggestDateFromOcrText('EXP 14.07.2027');
    expect(result.status, AiExpiryDateStatus.failed);
    expect(result.date, isNull);
  });

  test('parses date from image input', () async {
    late String capturedBody;
    final client = AiExpiryDateClient(
      apiKey: 'test-key',
      httpClient: MockClient((request) async {
        capturedBody = request.body;
        return http.Response('{"output_text":"2027-07-14"}', 200);
      }),
    );

    final result = await client.suggestDateFromImageBytes(
      Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(result.status, AiExpiryDateStatus.found);
    expect(result.date, DateTime(2027, 7, 14));
    expect(result.source, AiExpiryDateSource.image);
    expect(capturedBody, contains('"type":"input_image"'));
    expect(capturedBody, contains('data:image/jpeg;base64,'));
  });
}
