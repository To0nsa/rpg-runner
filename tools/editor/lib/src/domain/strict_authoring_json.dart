import 'dart:convert';

import '../chunks/chunk_domain_models.dart';

/// Fail-closed JSON primitives shared by strict authoring source codecs.
///
/// These helpers validate the authored representation as written. They never
/// trim, default, reorder, or coerce values, because doing so would hide source
/// drift before a migration plan is reviewed.
abstract final class StrictAuthoringJson {
  /// Decodes [raw] as one JSON object and reports failures at [sourcePath].
  static Map<String, Object?> decodeRoot(
    String raw, {
    required String sourcePath,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('$sourcePath is malformed JSON: ${error.message}');
    }
    return object(decoded, sourcePath: sourcePath);
  }

  /// Requires an object with string keys without changing its values.
  static Map<String, Object?> object(
    Object? raw, {
    required String sourcePath,
  }) {
    if (raw is! Map<Object?, Object?> ||
        raw.keys.any((key) => key is! String)) {
      throw FormatException('$sourcePath must be an object.');
    }
    return <String, Object?>{
      for (final entry in raw.entries) entry.key! as String: entry.value,
    };
  }

  /// Parses an array of objects while retaining its authored order.
  static List<T> objectList<T>(
    Object? raw, {
    required String sourcePath,
    required T Function(Map<String, Object?> json, {required String sourcePath})
    parse,
  }) {
    if (raw is! List<Object?>) {
      throw FormatException('$sourcePath must be an array.');
    }
    return <T>[
      for (var index = 0; index < raw.length; index += 1)
        parse(
          object(raw[index], sourcePath: '$sourcePath[$index]'),
          sourcePath: '$sourcePath[$index]',
        ),
    ];
  }

  /// Rejects missing and unknown object fields.
  static void requireKeys(
    Map<String, Object?> json, {
    required String sourcePath,
    required Set<String> allowed,
    required Set<String> required,
  }) {
    final unknown = json.keys.where((key) => !allowed.contains(key)).toList()
      ..sort();
    if (unknown.isNotEmpty) {
      throw FormatException('$sourcePath has unknown field ${unknown.first}.');
    }
    final missing = required.where((key) => !json.containsKey(key)).toList()
      ..sort();
    if (missing.isNotEmpty) {
      throw FormatException('$sourcePath is missing field ${missing.first}.');
    }
  }

  /// Requires an exact integer schema version.
  static void requireSchemaVersion(
    Object? raw,
    int expected, {
    required String sourcePath,
  }) {
    if (raw is! int || raw != expected) {
      throw FormatException('$sourcePath must be exactly $expected.');
    }
  }

  /// Requires a non-empty string with no surrounding whitespace.
  static String nonEmptyString(Object? raw, {required String sourcePath}) {
    if (raw is! String || raw.isEmpty || raw.trim() != raw) {
      throw FormatException('$sourcePath must be a non-empty trimmed string.');
    }
    return raw;
  }

  /// Requires one exact value from [accepted].
  static String enumString(
    Object? raw,
    Set<String> accepted, {
    required String sourcePath,
  }) {
    final value = nonEmptyString(raw, sourcePath: sourcePath);
    if (!accepted.contains(value)) {
      final choices = accepted.toList()..sort();
      throw FormatException(
        '$sourcePath must be one of ${choices.join(', ')}.',
      );
    }
    return value;
  }

  /// Requires a JSON integer without numeric coercion.
  static int integer(Object? raw, {required String sourcePath}) {
    if (raw is! int) throw FormatException('$sourcePath must be an integer.');
    return raw;
  }

  /// Requires a positive JSON integer without numeric coercion.
  static int positiveInt(Object? raw, {required String sourcePath}) {
    final value = integer(raw, sourcePath: sourcePath);
    if (value <= 0) throw FormatException('$sourcePath must be positive.');
    return value;
  }

  /// Requires an exact JSON boolean.
  static bool boolean(Object? raw, {required String sourcePath}) {
    if (raw is! bool) throw FormatException('$sourcePath must be a boolean.');
    return raw;
  }

  /// Requires the editor's canonical prefab placement scale contract.
  static double prefabScale(Object? raw, {required String sourcePath}) {
    if (raw is! num || !raw.isFinite) {
      throw FormatException('$sourcePath must be a finite number.');
    }
    final value = raw.toDouble();
    if (!isPrefabPlacementScaleInRange(value) ||
        !isPrefabPlacementScaleStepAligned(value)) {
      throw FormatException(
        '$sourcePath must use an accepted 0.3-3.0 scale in 0.1 steps.',
      );
    }
    return canonicalPrefabPlacementScale(value);
  }

  /// Requires sorted, unique, non-empty tags without normalization.
  static List<String> canonicalTags(Object? raw, {required String sourcePath}) {
    if (raw is! List<Object?>) {
      throw FormatException('$sourcePath must be an array.');
    }
    final tags = <String>[];
    for (var index = 0; index < raw.length; index += 1) {
      tags.add(nonEmptyString(raw[index], sourcePath: '$sourcePath[$index]'));
    }
    requireStrictStringOrder(tags, sourcePath: sourcePath);
    return tags;
  }

  /// Requires ascending string order with no duplicates.
  static void requireStrictStringOrder(
    Iterable<String> values, {
    required String sourcePath,
  }) {
    String? previous;
    for (final value in values) {
      if (previous != null && previous.compareTo(value) >= 0) {
        throw FormatException(
          '$sourcePath must be strictly ordered with no duplicates.',
        );
      }
      previous = value;
    }
  }

  /// Requires unique string identities, optionally ignoring case.
  static void requireUniqueStrings(
    Iterable<String> values, {
    required String sourcePath,
    required bool caseInsensitive,
  }) {
    final seen = <String>{};
    for (final value in values) {
      final identity = caseInsensitive ? value.toLowerCase() : value;
      if (!seen.add(identity)) {
        throw FormatException('$sourcePath must contain unique values.');
      }
    }
  }

  /// Requires that [values] are already in strict comparator order.
  static void requireComparatorOrder<T>(
    List<T> values,
    int Function(T left, T right) compare, {
    required String sourcePath,
  }) {
    for (var index = 1; index < values.length; index += 1) {
      if (compare(values[index - 1], values[index]) >= 0) {
        throw FormatException(
          '$sourcePath must be in canonical order without duplicates.',
        );
      }
    }
  }

  /// Emits canonical indented JSON with one final newline.
  static String encode(Map<String, Object> json) =>
      '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
