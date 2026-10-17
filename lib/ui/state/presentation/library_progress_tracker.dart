/// Remembers which Library values have already been presented in this app session.
/// It never changes account progress or unlock eligibility.
final class LibraryProgressTracker {
  String? _accountKey;
  final Map<String, int> _presented = {};

  /// Returns the last presented value and records [current] as consumed.
  /// The first value for an entry appears immediately. Switching accounts
  /// starts a fresh presentation history.
  int consume(String accountKey, String entryKey, int current) {
    if (_accountKey != accountKey) {
      _accountKey = accountKey;
      _presented.clear();
    }
    final previous = _presented[entryKey] ?? current;
    _presented[entryKey] = current;
    return previous;
  }
}
