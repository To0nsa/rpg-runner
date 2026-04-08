/// Shared JSON normalization helpers for prefab model parsers.
///
/// Keeping this logic centralized prevents subtle drift where different model
/// types trim strings or map object keys differently.
class PrefabModelJson {
  const PrefabModelJson._();

  /// Returns a trimmed string value or [fallback] when [raw] is not a string.
  static String normalizedString(Object? raw, {String fallback = ''}) {
    if (raw is String) {
      return raw.trim();
    }
    return fallback;
  }

  /// Coerces loosely-typed decoded JSON maps into `Map<String, Object?>`.
  ///
  /// Non-string keys are dropped so malformed payload fragments can be skipped
  /// deterministically instead of throwing in every parser.
  static Map<String, Object?>? asObjectMap(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      return null;
    }
    final mapped = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      mapped[key] = entry.value;
    }
    return mapped;
  }
}
