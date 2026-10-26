/// Largest integer represented exactly by both Dart and JavaScript JSON users.
const int maxJsonSafeInteger = 9007199254740991;

/// Rejects integers that cannot round-trip through the shared wire contract.
/// Null is allowed for optional fields; domain-specific bounds remain with the
/// containing value object.
void requireJsonSafeInteger(int? value, String name) {
  if (value != null &&
      (value < -maxJsonSafeInteger || value > maxJsonSafeInteger)) {
    throw ArgumentError.value(value, name, 'must be a JSON-safe integer');
  }
}
