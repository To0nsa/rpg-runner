import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'codecs/json_integer.dart';

/// Cross-language ticket-loadout hashing, independent of replay-v1 encoding.
///
/// Numbers must be safe integers (integral doubles are normalized to integers),
/// strings must be well-formed Unicode, object keys sort by UTF-16 code units,
/// and list order is preserved. Invalid local payloads throw [ArgumentError].
/// Existing authorized loadouts retain their original digests.
abstract final class LoadoutDigest {
  static String canonicalJson(Map<String, Object?> loadout) => _encode(loadout);

  static String sha256ForMap(Map<String, Object?> loadout) =>
      sha256.convert(utf8.encode(canonicalJson(loadout))).toString();

  static String _encode(Object? value) {
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw ArgumentError('Loadout JSON requires string object keys.');
      }
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${_string(key)}:${_encode(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_encode).join(',')}]';
    }
    if (value is num) {
      if (!value.isFinite ||
          value < -maxJsonSafeInteger ||
          value > maxJsonSafeInteger ||
          value != value.roundToDouble()) {
        throw ArgumentError('Loadout JSON numbers must be safe integers.');
      }
      return value.toInt().toString();
    }
    if (value is String) return _string(value);
    if (value == null || value is bool) return jsonEncode(value);
    throw ArgumentError(
      'Unsupported loadout JSON value: ${value.runtimeType}.',
    );
  }

  static String _string(String value) {
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++i >= value.length ||
            value.codeUnitAt(i) < 0xdc00 ||
            value.codeUnitAt(i) > 0xdfff) {
          throw ArgumentError('Loadout JSON requires well-formed Unicode.');
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        throw ArgumentError('Loadout JSON requires well-formed Unicode.');
      }
    }
    return jsonEncode(value);
  }
}
