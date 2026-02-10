String? pickFirstBarcodeValue(Iterable<String?> values) {
  for (final value in values) {
    final candidate = value?.trim() ?? '';
    if (_looksLikeProductBarcode(candidate)) {
      return candidate;
    }
  }
  return null;
}

bool _looksLikeProductBarcode(String value) {
  if (value.isEmpty) {
    return false;
  }

  // Product barcodes are numeric (EAN/UPC/GTIN). This filters QR URLs/text.
  return RegExp(r'^\d{8,14}$').hasMatch(value);
}
