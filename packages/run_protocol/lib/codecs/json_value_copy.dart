import 'dart:collection';

/// Returns a recursively immutable copy of a JSON object.
///
/// Contract values retain this copy so callers cannot alter a digest-bound
/// payload after construction.
Map<String, Object?> immutableJsonObject(
  Map<String, Object?> value, {
  required String fieldName,
}) {
  return _copyJsonValue(value, fieldName: fieldName, immutable: true)
      as Map<String, Object?>;
}

/// Returns a detached mutable copy of a JSON object for serialization.
Map<String, Object?> mutableJsonObjectCopy(
  Map<String, Object?> value, {
  required String fieldName,
}) {
  return _copyJsonValue(value, fieldName: fieldName, immutable: false)
      as Map<String, Object?>;
}

Object? _copyJsonValue(
  Object? value, {
  required String fieldName,
  required bool immutable,
}) {
  if (value is Map) {
    final copy = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          value,
          fieldName,
          'must contain only string object keys',
        );
      }
      copy[key] = _copyJsonValue(
        entry.value,
        fieldName: '$fieldName.$key',
        immutable: immutable,
      );
    }
    return immutable ? UnmodifiableMapView<String, Object?>(copy) : copy;
  }
  if (value is List) {
    final copy = <Object?>[
      for (var index = 0; index < value.length; index += 1)
        _copyJsonValue(
          value[index],
          fieldName: '$fieldName[$index]',
          immutable: immutable,
        ),
    ];
    return immutable ? UnmodifiableListView<Object?>(copy) : copy;
  }
  if (value is num && !value.toDouble().isFinite) {
    throw ArgumentError.value(value, fieldName, 'must contain finite numbers');
  }
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  throw ArgumentError.value(
    value,
    fieldName,
    'must contain only JSON-compatible values',
  );
}
