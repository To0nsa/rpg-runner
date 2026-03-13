import 'dart:convert';

/// Encodes [value] to deterministic JSON by recursively sorting object keys.
String canonicalJsonEncode(Object? value) {
  return jsonEncode(_normalize(value));
}

Object? _normalize(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    final out = <String, Object?>{};
    for (final entry in entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('Canonical JSON requires string object keys.');
      }
      out[key] = _normalize(entry.value);
    }
    return out;
  }

  if (value is List) {
    return value.map(_normalize).toList(growable: false);
  }

  if (value == null ||
      value is bool ||
      value is num ||
      value is String) {
    return value;
  }

  throw FormatException('Unsupported JSON value type: ${value.runtimeType}.');
}
