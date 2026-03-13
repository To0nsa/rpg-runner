Map<String, Object?> asObjectMap(
  Object? raw, {
  required String fieldName,
}) {
  if (raw is! Map) {
    throw FormatException('$fieldName must be a JSON object.');
  }
  final out = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$fieldName contains a non-string key.');
    }
    out[key] = entry.value;
  }
  return out;
}

String readRequiredString(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw is! String || raw.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return raw;
}

String? readOptionalString(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! String || raw.isEmpty) {
    throw FormatException('$key must be a non-empty string when set.');
  }
  return raw;
}

int readRequiredInt(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw is! num) {
    throw FormatException('$key must be a number.');
  }
  if (raw is! int && raw != raw.roundToDouble()) {
    throw FormatException('$key must be an integer.');
  }
  return raw.toInt();
}

int? readOptionalInt(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! num) {
    throw FormatException('$key must be a number when set.');
  }
  if (raw is! int && raw != raw.roundToDouble()) {
    throw FormatException('$key must be an integer when set.');
  }
  return raw.toInt();
}

double readRequiredDouble(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw is! num) {
    throw FormatException('$key must be a number.');
  }
  return raw.toDouble();
}

double? readOptionalDouble(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  if (raw is! num) {
    throw FormatException('$key must be a number when set.');
  }
  return raw.toDouble();
}

bool readRequiredBool(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw is! bool) {
    throw FormatException('$key must be a bool.');
  }
  return raw;
}

Map<String, Object?> readRequiredObject(Map<String, Object?> json, String key) {
  return asObjectMap(json[key], fieldName: key);
}

Map<String, Object?>? readOptionalObject(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  return asObjectMap(raw, fieldName: key);
}

List<Object?> readRequiredList(Map<String, Object?> json, String key) {
  final raw = json[key];
  if (raw is! List) {
    throw FormatException('$key must be a JSON array.');
  }
  return raw.cast<Object?>();
}
