import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

enum AiExpiryDateStatus { disabled, emptyInput, found, noDate, failed }

enum AiExpiryDateSource { none, text, image }

class AiExpiryDateResult {
  const AiExpiryDateResult({
    required this.status,
    this.date,
    this.source = AiExpiryDateSource.none,
  });

  final AiExpiryDateStatus status;
  final DateTime? date;
  final AiExpiryDateSource source;
}

class AiExpiryDateClient {
  AiExpiryDateClient({
    String? apiKey,
    http.Client? httpClient,
    this.model = 'gpt-4.1-mini',
  }) : _apiKey = (apiKey ?? const String.fromEnvironment('OPENAI_API_KEY'))
           .trim(),
       _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _httpClient;
  final String model;

  bool get isEnabled => _apiKey.isNotEmpty;

  Future<AiExpiryDateResult> suggestDateFromOcrText(String ocrText) async {
    if (!isEnabled || ocrText.trim().isEmpty) {
      return AiExpiryDateResult(
        status: isEnabled
            ? AiExpiryDateStatus.emptyInput
            : AiExpiryDateStatus.disabled,
      );
    }

    return _suggestFromContent(
      systemPrompt:
          'You extract expiration dates from OCR text. Reply with only one token: YYYY-MM-DD or NONE.',
      userContent: [
        {'type': 'input_text', 'text': ocrText},
      ],
      source: AiExpiryDateSource.text,
    );
  }

  Future<AiExpiryDateResult> suggestDateFromImageBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!isEnabled || imageBytes.isEmpty) {
      return AiExpiryDateResult(
        status: isEnabled
            ? AiExpiryDateStatus.emptyInput
            : AiExpiryDateStatus.disabled,
      );
    }

    final base64Image = base64Encode(imageBytes);
    final dataUrl = 'data:$mimeType;base64,$base64Image';
    return _suggestFromContent(
      systemPrompt:
          'You read expiration dates from product photos. Reply with only one token: YYYY-MM-DD or NONE.',
      userContent: [
        {
          'type': 'input_text',
          'text': 'Find the expiration date in this image.',
        },
        {'type': 'input_image', 'image_url': dataUrl},
      ],
      source: AiExpiryDateSource.image,
    );
  }

  Future<AiExpiryDateResult> _suggestFromContent({
    required String systemPrompt,
    required List<Map<String, dynamic>> userContent,
    required AiExpiryDateSource source,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'temperature': 0,
          'input': [
            {
              'role': 'system',
              'content': [
                {'type': 'input_text', 'text': systemPrompt},
              ],
            },
            {'role': 'user', 'content': userContent},
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const AiExpiryDateResult(status: AiExpiryDateStatus.failed);
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return const AiExpiryDateResult(status: AiExpiryDateStatus.failed);
      }

      final outputText = _extractOutputText(payload);
      final date = _parseDateToken(outputText);
      if (date == null) {
        return const AiExpiryDateResult(status: AiExpiryDateStatus.noDate);
      }
      return AiExpiryDateResult(
        status: AiExpiryDateStatus.found,
        date: date,
        source: source,
      );
    } catch (_) {
      return const AiExpiryDateResult(status: AiExpiryDateStatus.failed);
    }
  }

  String _extractOutputText(Map<String, dynamic> payload) {
    final topLevel = payload['output_text'];
    if (topLevel is String && topLevel.trim().isNotEmpty) {
      return topLevel.trim();
    }

    final output = payload['output'];
    if (output is List) {
      for (final block in output) {
        if (block is! Map<String, dynamic>) {
          continue;
        }
        final content = block['content'];
        if (content is! List) {
          continue;
        }
        for (final chunk in content) {
          if (chunk is! Map<String, dynamic>) {
            continue;
          }
          final text = chunk['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      }
    }

    return '';
  }

  DateTime? _parseDateToken(String text) {
    final token = text.trim();
    if (token.isEmpty || token.toUpperCase() == 'NONE') {
      return null;
    }

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(token);
    if (match == null) {
      return null;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    try {
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
