enum RunMode {
  practice,
  competitive,
  weekly;

  bool get requiresBoard => this != RunMode.practice;

  static RunMode parse(Object? raw, {String fieldName = 'mode'}) {
    if (raw is! String) {
      throw FormatException('$fieldName must be a string.');
    }
    return switch (raw) {
      'practice' => RunMode.practice,
      'competitive' => RunMode.competitive,
      'weekly' => RunMode.weekly,
      _ => throw FormatException(
        '$fieldName must be one of: practice|competitive|weekly.',
      ),
    };
  }
}
