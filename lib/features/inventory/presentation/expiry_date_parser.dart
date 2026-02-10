class ExpiryDateAnalysis {
  ExpiryDateAnalysis({
    required this.ocrText,
    required this.candidates,
    this.suggestedDate,
  });

  final String ocrText;
  final List<DateTime> candidates;
  final DateTime? suggestedDate;
}

ExpiryDateAnalysis analyzeExpirationDateText(
  String rawText, {
  DateTime? now,
}) {
  final baseline = now ?? DateTime.now();
  final today = DateTime(baseline.year, baseline.month, baseline.day);

  final scoreByDate = <DateTime, int>{};

  void addCandidate(DateTime date, int score) {
    final normalized = DateTime(date.year, date.month, date.day);
    final currentScore = scoreByDate[normalized];
    if (currentScore == null || score > currentScore) {
      scoreByDate[normalized] = score;
    }
  }

  void addIfValid(
    int year,
    int month,
    int day,
    int score,
  ) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return;
    }

    DateTime candidate;
    try {
      candidate = DateTime(year, month, day);
    } catch (_) {
      return;
    }

    if (candidate.year != year || candidate.month != month || candidate.day != day) {
      return;
    }

    final minDate = today.subtract(const Duration(days: 1));
    final maxDate = DateTime(today.year + 30, today.month, today.day);
    if (candidate.isBefore(minDate) || candidate.isAfter(maxDate)) {
      return;
    }

    addCandidate(candidate, score);
  }

  final separators = r'[.,\/-]';
  final ymd = RegExp(r'\b(20\d{2})' + separators + r'(\d{1,2})' + separators + r'(\d{1,2})\b');
  final dmy = RegExp(r'\b(\d{1,2})' + separators + r'(\d{1,2})' + separators + r'(\d{2,4})\b');
  final dmNoYear = RegExp(
    r'\b(\d{1,2})' + separators + r'(\d{1,2})\b(?!' + separators + r'\d{2,4})',
  );
  final expiryKeywords = RegExp(
    r'(exp|best before|use by|bbe|bb|lej[aá]r|fogyaszthat|min[oő]s[eé]g)',
    caseSensitive: false,
  );
  final productionKeywords = RegExp(
    r'(mfg|packed|prod|gy[aá]rt)',
    caseSensitive: false,
  );

  final lines = rawText.split(RegExp(r'[\r\n]+'));
  for (final line in lines) {
    var score = 0;
    if (expiryKeywords.hasMatch(line)) {
      score += 2;
    }
    if (productionKeywords.hasMatch(line)) {
      score -= 1;
    }

    for (final match in ymd.allMatches(line)) {
      addIfValid(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        score,
      );
    }

    for (final match in dmy.allMatches(line)) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) {
        year += 2000;
      }
      addIfValid(year, month, day, score);
    }

    for (final match in dmNoYear.allMatches(line)) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = today.year;

      addIfValid(year, month, day, score);
      final date = DateTime(year, month, day);
      if (date.isBefore(today.subtract(const Duration(days: 7)))) {
        year += 1;
        addIfValid(year, month, day, score);
      }
    }
  }

  final entries = scoreByDate.entries.toList()
    ..sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) {
        return byScore;
      }
      return a.key.compareTo(b.key);
    });

  final candidates = entries.map((e) => e.key).toList(growable: false);
  return ExpiryDateAnalysis(
    ocrText: rawText,
    candidates: candidates,
    suggestedDate: candidates.isEmpty ? null : candidates.first,
  );
}

DateTime? suggestExpirationDateFromText(
  String rawText, {
  DateTime? now,
}) {
  return analyzeExpirationDateText(rawText, now: now).suggestedDate;
}
