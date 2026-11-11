enum RunMode {
  practice,
  campaign,
  competitive,
  weekly;

  bool get requiresBoard =>
      this == RunMode.competitive || this == RunMode.weekly;

  static RunMode parse(Object? raw, {String fieldName = 'mode'}) {
    if (raw is! String) {
      throw FormatException('$fieldName must be a string.');
    }
    return switch (raw) {
      'practice' => RunMode.practice,
      'campaign' => RunMode.campaign,
      'competitive' => RunMode.competitive,
      'weekly' => RunMode.weekly,
      _ => throw FormatException(
        '$fieldName must be one of: practice|campaign|competitive|weekly.',
      ),
    };
  }
}
