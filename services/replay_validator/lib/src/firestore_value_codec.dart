import 'package:googleapis/firestore/v1.dart' as firestore;

Map<String, firestore.Value> encodeFirestoreFields(Map<String, Object?> map) {
  return map.map(
    (String key, Object? value) => MapEntry<String, firestore.Value>(
      key,
      encodeFirestoreValue(value),
    ),
  );
}

firestore.Value encodeFirestoreValue(Object? value) {
  if (value == null) {
    return firestore.Value(nullValue: 'NULL_VALUE');
  }
  if (value is bool) {
    return firestore.Value(booleanValue: value);
  }
  if (value is int) {
    return firestore.Value(integerValue: value.toString());
  }
  if (value is double) {
    return firestore.Value(doubleValue: value);
  }
  if (value is num) {
    if (value == value.roundToDouble()) {
      return firestore.Value(integerValue: value.toInt().toString());
    }
    return firestore.Value(doubleValue: value.toDouble());
  }
  if (value is String) {
    return firestore.Value(stringValue: value);
  }
  if (value is List) {
    return firestore.Value(
      arrayValue: firestore.ArrayValue(
        values: value.map(encodeFirestoreValue).toList(growable: false),
      ),
    );
  }
  if (value is Map) {
    final out = <String, firestore.Value>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError(
          'Firestore map keys must be strings. Got key type ${key.runtimeType}.',
        );
      }
      out[key] = encodeFirestoreValue(entry.value);
    }
    return firestore.Value(
      mapValue: firestore.MapValue(fields: out),
    );
  }
  throw ArgumentError('Unsupported Firestore value type: ${value.runtimeType}');
}

Map<String, Object?> decodeFirestoreFields(Map<String, firestore.Value>? fields) {
  if (fields == null || fields.isEmpty) {
    return const <String, Object?>{};
  }
  return fields.map(
    (String key, firestore.Value value) => MapEntry<String, Object?>(
      key,
      decodeFirestoreValue(value),
    ),
  );
}

Object? decodeFirestoreValue(firestore.Value value) {
  if (value.nullValue != null) {
    return null;
  }
  if (value.booleanValue != null) {
    return value.booleanValue;
  }
  if (value.stringValue != null) {
    return value.stringValue;
  }
  if (value.integerValue != null) {
    return int.tryParse(value.integerValue!);
  }
  if (value.doubleValue != null) {
    return value.doubleValue;
  }
  if (value.timestampValue != null) {
    return value.timestampValue;
  }
  if (value.referenceValue != null) {
    return value.referenceValue;
  }
  if (value.bytesValue != null) {
    return value.bytesValue;
  }
  if (value.arrayValue?.values != null) {
    return value.arrayValue!.values!
        .map<Object?>(decodeFirestoreValue)
        .toList(growable: false);
  }
  if (value.mapValue?.fields != null) {
    return decodeFirestoreFields(value.mapValue!.fields);
  }
  return null;
}
