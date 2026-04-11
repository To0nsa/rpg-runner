import 'dart:convert';
import 'dart:io';

const int levelDefsSchemaVersion = 1;

const String activeLevelStatus = 'active';
const String deprecatedLevelStatus = 'deprecated';

const Set<String> _supportedLevelStatuses = <String>{
  activeLevelStatus,
  deprecatedLevelStatus,
};

final RegExp _stableIdentifierPattern = RegExp(r'^[a-z][a-z0-9_]*$');

Future<LevelDefsLoadResult> loadLevelDefinitions({
  required String defsPath,
}) async {
  final issues = <LevelDefinitionValidationIssue>[];
  final file = File(defsPath);
  if (!await file.exists()) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'missing_file',
        message: 'Required file is missing.',
      ),
    );
    return const LevelDefsLoadResult(
      levels: <LevelDefinitionSource>[],
      issues: <LevelDefinitionValidationIssue>[],
    ).copyWith(issues: issues);
  }

  late final String raw;
  try {
    raw = await file.readAsString();
  } on Object catch (error) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'read_failed',
        message: 'Unable to read file: $error',
      ),
    );
    return LevelDefsLoadResult(
      levels: const <LevelDefinitionSource>[],
      issues: issues,
    );
  }

  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on Object catch (error) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_json',
        message: 'JSON parse error: $error',
      ),
    );
    return LevelDefsLoadResult(
      levels: const <LevelDefinitionSource>[],
      issues: issues,
    );
  }

  if (decoded is! Map<String, Object?>) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_root_type',
        message: 'Top-level JSON value must be an object.',
      ),
    );
    return LevelDefsLoadResult(
      levels: const <LevelDefinitionSource>[],
      issues: issues,
    );
  }

  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion is! int || schemaVersion != levelDefsSchemaVersion) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_schema_version',
        message: 'schemaVersion must be the integer $levelDefsSchemaVersion.',
      ),
    );
  }

  final rawLevels = decoded['levels'];
  if (rawLevels is! List<Object?>) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_levels_array',
        message: 'levels must be an array of objects.',
      ),
    );
    return LevelDefsLoadResult(
      levels: const <LevelDefinitionSource>[],
      issues: issues,
    );
  }

  final levels = <LevelDefinitionSource>[];
  final seenLevelIds = <String>{};
  final seenEnumOrdinals = <int>{};
  for (var i = 0; i < rawLevels.length; i += 1) {
    final entry = rawLevels[i];
    if (entry is! Map<String, Object?>) {
      issues.add(
        LevelDefinitionValidationIssue(
          path: defsPath,
          code: 'invalid_level_entry',
          message: 'levels[$i] must be an object.',
        ),
      );
      continue;
    }
    final level = _parseLevelEntry(
      entry,
      defsPath: defsPath,
      levelIndex: i,
      issues: issues,
    );
    if (level == null) {
      continue;
    }
    if (!seenLevelIds.add(level.levelId)) {
      issues.add(
        LevelDefinitionValidationIssue(
          path: defsPath,
          code: 'duplicate_level_id',
          message: 'levelId "${level.levelId}" is duplicated.',
        ),
      );
      continue;
    }
    if (!seenEnumOrdinals.add(level.enumOrdinal)) {
      issues.add(
        LevelDefinitionValidationIssue(
          path: defsPath,
          code: 'duplicate_enum_ordinal',
          message: 'enumOrdinal ${level.enumOrdinal} is duplicated.',
        ),
      );
      continue;
    }
    levels.add(level);
  }

  levels.sort(_compareLevels);

  if (issues.isEmpty) {
    final canonical = renderCanonicalLevelDefsJson(levels);
    if (_normalizeNewlines(raw) != canonical) {
      issues.add(
        LevelDefinitionValidationIssue(
          path: defsPath,
          code: 'non_canonical_level_defs',
          message:
              'level_defs.json must use canonical field order, list order, '
              'identifier normalization, and numeric formatting.',
        ),
      );
    }
  }

  return LevelDefsLoadResult(
    levels: List<LevelDefinitionSource>.unmodifiable(levels),
    issues: List<LevelDefinitionValidationIssue>.unmodifiable(issues),
  );
}

LevelDefinitionSource? _parseLevelEntry(
  Map<String, Object?> entry, {
  required String defsPath,
  required int levelIndex,
  required List<LevelDefinitionValidationIssue> issues,
}) {
  final fieldPrefix = 'levels[$levelIndex]';
  final levelId = _readRequiredString(
    entry,
    field: 'levelId',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final revision = _readRequiredPositiveInt(
    entry,
    field: 'revision',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final displayName = _readRequiredString(
    entry,
    field: 'displayName',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final themeId = _readRequiredString(
    entry,
    field: 'themeId',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final cameraCenterY = _readRequiredFiniteDouble(
    entry,
    field: 'cameraCenterY',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final groundTopY = _readRequiredFiniteDouble(
    entry,
    field: 'groundTopY',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final earlyPatternChunks = _readRequiredNonNegativeInt(
    entry,
    field: 'earlyPatternChunks',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final easyPatternChunks = _readRequiredNonNegativeInt(
    entry,
    field: 'easyPatternChunks',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final normalPatternChunks = _readRequiredNonNegativeInt(
    entry,
    field: 'normalPatternChunks',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final noEnemyChunks = _readRequiredNonNegativeInt(
    entry,
    field: 'noEnemyChunks',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final enumOrdinal = _readRequiredPositiveInt(
    entry,
    field: 'enumOrdinal',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );
  final status = _readRequiredString(
    entry,
    field: 'status',
    issues: issues,
    path: defsPath,
    fieldPrefix: fieldPrefix,
  );

  if (levelId.isNotEmpty && !_stableIdentifierPattern.hasMatch(levelId)) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_level_id',
        message:
            '$fieldPrefix.levelId must match ${_stableIdentifierPattern.pattern}.',
      ),
    );
  }
  if (themeId.isNotEmpty && !_stableIdentifierPattern.hasMatch(themeId)) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_theme_id',
        message:
            '$fieldPrefix.themeId must match ${_stableIdentifierPattern.pattern}.',
      ),
    );
  }
  if (status.isNotEmpty && !_supportedLevelStatuses.contains(status)) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: defsPath,
        code: 'invalid_status',
        message:
            '$fieldPrefix.status must be "$activeLevelStatus" or '
            '"$deprecatedLevelStatus".',
      ),
    );
  }

  if (levelId.isEmpty ||
      revision == null ||
      displayName.isEmpty ||
      themeId.isEmpty ||
      cameraCenterY == null ||
      groundTopY == null ||
      earlyPatternChunks == null ||
      easyPatternChunks == null ||
      normalPatternChunks == null ||
      noEnemyChunks == null ||
      enumOrdinal == null ||
      status.isEmpty) {
    return null;
  }

  return LevelDefinitionSource(
    levelId: levelId,
    revision: revision,
    displayName: displayName,
    themeId: themeId,
    cameraCenterY: _normalizeZero(cameraCenterY),
    groundTopY: _normalizeZero(groundTopY),
    earlyPatternChunks: earlyPatternChunks,
    easyPatternChunks: easyPatternChunks,
    normalPatternChunks: normalPatternChunks,
    noEnemyChunks: noEnemyChunks,
    enumOrdinal: enumOrdinal,
    status: status,
  );
}

String renderCanonicalLevelDefsJson(List<LevelDefinitionSource> levels) {
  final sortedLevels = List<LevelDefinitionSource>.from(levels)
    ..sort(_compareLevels);

  final buffer = StringBuffer()..writeln('{');
  buffer.writeln('  "schemaVersion": $levelDefsSchemaVersion,');
  buffer.writeln('  "levels": [');
  for (var i = 0; i < sortedLevels.length; i += 1) {
    final level = sortedLevels[i];
    buffer.writeln('    {');
    buffer.writeln('      "levelId": ${jsonEncode(level.levelId)},');
    buffer.writeln('      "revision": ${level.revision},');
    buffer.writeln('      "displayName": ${jsonEncode(level.displayName)},');
    buffer.writeln('      "themeId": ${jsonEncode(level.themeId)},');
    buffer.writeln(
      '      "cameraCenterY": ${_formatCanonicalNumber(level.cameraCenterY)},',
    );
    buffer.writeln(
      '      "groundTopY": ${_formatCanonicalNumber(level.groundTopY)},',
    );
    buffer.writeln('      "earlyPatternChunks": ${level.earlyPatternChunks},');
    buffer.writeln('      "easyPatternChunks": ${level.easyPatternChunks},');
    buffer.writeln(
      '      "normalPatternChunks": ${level.normalPatternChunks},',
    );
    buffer.writeln('      "noEnemyChunks": ${level.noEnemyChunks},');
    buffer.writeln('      "enumOrdinal": ${level.enumOrdinal},');
    buffer.writeln('      "status": ${jsonEncode(level.status)}');
    buffer.write('    }');
    if (i < sortedLevels.length - 1) {
      buffer.write(',');
    }
    buffer.writeln();
  }
  buffer.writeln('  ]');
  buffer.writeln('}');
  return buffer.toString();
}

String renderLevelIdDartOutput(List<LevelDefinitionSource> levels) {
  final enumOrderedLevels = _levelsInEnumOrder(levels);
  final values = enumOrderedLevels.map((level) => level.levelId).join(', ');
  final buffer = StringBuffer()
    ..writeln('/// GENERATED FILE. DO NOT EDIT BY HAND.')
    ..writeln('///')
    ..writeln('/// Generated by tool/generate_chunk_runtime_data.dart from:')
    ..writeln('/// - `assets/authoring/level/level_defs.json`')
    ..writeln('/// Stable identifiers for level definitions.')
    ..writeln('///')
    ..writeln(
      '/// Avoid renaming or reordering values; treat as protocol-stable.',
    )
    ..writeln('enum LevelId { $values }');
  return buffer.toString();
}

String renderLevelRegistryDartOutput(List<LevelDefinitionSource> levels) {
  final enumOrderedLevels = _levelsInEnumOrder(levels);
  final canonicalLevels = List<LevelDefinitionSource>.from(levels)
    ..sort(_compareLevels);
  if (canonicalLevels.isEmpty) {
    throw StateError('Cannot render level registry without authored levels.');
  }
  final defaultChunkPatternLevelId = canonicalLevels.first.levelId;

  final buffer = StringBuffer()
    ..writeln('/// GENERATED FILE. DO NOT EDIT BY HAND.')
    ..writeln('///')
    ..writeln('/// Generated by tool/generate_chunk_runtime_data.dart from:')
    ..writeln('/// - `assets/authoring/level/level_defs.json`')
    ..writeln('/// Registry for core level definitions.')
    ..writeln('library;')
    ..writeln()
    ..writeln("import '../collision/static_world_geometry.dart';")
    ..writeln("import '../track/authored_chunk_patterns.dart';")
    ..writeln("import '../track/chunk_pattern_source.dart';")
    ..writeln("import 'level_definition.dart';")
    ..writeln("import 'level_id.dart';")
    ..writeln()
    ..writeln('/// Default runtime-authored chunk pattern source.')
    ..writeln('final ChunkPatternSource defaultChunkPatternSource =')
    ..writeln(
      '    authoredChunkPatternSourceForLevel(LevelId.$defaultChunkPatternLevelId.name);',
    )
    ..writeln();

  for (final level in enumOrderedLevels) {
    final geometryVariable = '_${level.levelId}BaseGeometry';
    buffer
      ..writeln(
        'const StaticWorldGeometry $geometryVariable = StaticWorldGeometry(',
      )
      ..writeln(
        '  groundPlane: StaticGroundPlane(topY: ${_formatDartDouble(level.groundTopY)}),',
      )
      ..writeln(');')
      ..writeln();
  }

  buffer
    ..writeln('/// Resolves level definitions by stable [LevelId].')
    ..writeln('class LevelRegistry {')
    ..writeln('  const LevelRegistry._();')
    ..writeln()
    ..writeln('  /// Returns the level definition for a given [LevelId].')
    ..writeln('  static LevelDefinition byId(LevelId id) {')
    ..writeln('    switch (id) {');

  for (final level in enumOrderedLevels) {
    final geometryVariable = '_${level.levelId}BaseGeometry';
    buffer
      ..writeln('      case LevelId.${level.levelId}:')
      ..writeln('        return LevelDefinition(')
      ..writeln('          id: LevelId.${level.levelId},')
      ..writeln(
        '          chunkPatternSource: authoredChunkPatternSourceForLevel(',
      )
      ..writeln('            LevelId.${level.levelId}.name,')
      ..writeln('          ),')
      ..writeln(
        '          cameraCenterY: ${_formatDartDouble(level.cameraCenterY)},',
      )
      ..writeln('          staticWorldGeometry: $geometryVariable,')
      ..writeln('          earlyPatternChunks: ${level.earlyPatternChunks},')
      ..writeln('          easyPatternChunks: ${level.easyPatternChunks},')
      ..writeln('          normalPatternChunks: ${level.normalPatternChunks},')
      ..writeln('          noEnemyChunks: ${level.noEnemyChunks},')
      ..writeln("          themeId: '${_escape(level.themeId)}',")
      ..writeln('        );');
  }

  buffer
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('}');

  return buffer.toString();
}

String renderLevelUiMetadataDartOutput(List<LevelDefinitionSource> levels) {
  final enumOrderedLevels = _levelsInEnumOrder(levels);
  final selectableLevels = enumOrderedLevels
      .where((level) => level.status == activeLevelStatus)
      .toList(growable: false);
  final buffer = StringBuffer()
    ..writeln('/// GENERATED FILE. DO NOT EDIT BY HAND.')
    ..writeln('///')
    ..writeln('/// Generated by tool/generate_chunk_runtime_data.dart from:')
    ..writeln('/// - `assets/authoring/level/level_defs.json`')
    ..writeln('/// UI metadata for authored levels.')
    ..writeln('library;')
    ..writeln()
    ..writeln("import 'package:runner_core/levels/level_id.dart';")
    ..writeln()
    ..writeln('enum LevelUiStatus { active, deprecated }')
    ..writeln()
    ..writeln('class GeneratedLevelUiMetadata {')
    ..writeln('  const GeneratedLevelUiMetadata({')
    ..writeln('    required this.displayName,')
    ..writeln('    required this.status,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String displayName;')
    ..writeln('  final LevelUiStatus status;')
    ..writeln()
    ..writeln(
      '  bool get isSelectableInStandardUi => status == LevelUiStatus.active;',
    )
    ..writeln('}')
    ..writeln()
    ..writeln(
      'const Map<LevelId, GeneratedLevelUiMetadata> generatedLevelUiMetadataById =',
    )
    ..writeln('    <LevelId, GeneratedLevelUiMetadata>{');

  for (final level in enumOrderedLevels) {
    buffer
      ..writeln('  LevelId.${level.levelId}: GeneratedLevelUiMetadata(')
      ..writeln("    displayName: '${_escape(level.displayName)}',")
      ..writeln('    status: ${_renderLevelUiStatus(level.status)},')
      ..writeln('  ),');
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('const List<LevelId> generatedSelectableLevelIds = <LevelId>[');

  for (final level in selectableLevels) {
    buffer.writeln('  LevelId.${level.levelId},');
  }

  buffer
    ..writeln('];')
    ..writeln()
    ..writeln(
      'GeneratedLevelUiMetadata generatedLevelUiMetadataFor(LevelId levelId) {',
    )
    ..writeln('  final metadata = generatedLevelUiMetadataById[levelId];')
    ..writeln('  if (metadata != null) {')
    ..writeln('    return metadata;')
    ..writeln('  }')
    ..writeln(
      '  throw StateError(\'No generated UI metadata for levelId="\${levelId.name}".\');',
    )
    ..writeln('}');

  return buffer.toString();
}

int _compareLevels(LevelDefinitionSource a, LevelDefinitionSource b) {
  return a.levelId.compareTo(b.levelId);
}

int _compareLevelsByEnumOrdinal(
  LevelDefinitionSource a,
  LevelDefinitionSource b,
) {
  final ordinalCompare = a.enumOrdinal.compareTo(b.enumOrdinal);
  if (ordinalCompare != 0) {
    return ordinalCompare;
  }
  return a.levelId.compareTo(b.levelId);
}

List<LevelDefinitionSource> _levelsInEnumOrder(
  List<LevelDefinitionSource> levels,
) {
  final ordered = List<LevelDefinitionSource>.from(levels)
    ..sort(_compareLevelsByEnumOrdinal);
  return ordered;
}

String _readRequiredString(
  Map<String, Object?> map, {
  required String field,
  required List<LevelDefinitionValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final raw = map[field];
  if (raw is String) {
    final normalized = raw.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  issues.add(
    LevelDefinitionValidationIssue(
      path: path,
      code: 'missing_$field',
      message: '$fieldPrefix.$field must be a non-empty string.',
    ),
  );
  return '';
}

int? _readRequiredPositiveInt(
  Map<String, Object?> map, {
  required String field,
  required List<LevelDefinitionValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final value = _readRequiredInt(
    map,
    field: field,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (value == null) {
    return null;
  }
  if (value <= 0) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: path,
        code: 'invalid_$field',
        message: '$fieldPrefix.$field must be a positive integer.',
      ),
    );
    return null;
  }
  return value;
}

int? _readRequiredNonNegativeInt(
  Map<String, Object?> map, {
  required String field,
  required List<LevelDefinitionValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final value = _readRequiredInt(
    map,
    field: field,
    issues: issues,
    path: path,
    fieldPrefix: fieldPrefix,
  );
  if (value == null) {
    return null;
  }
  if (value < 0) {
    issues.add(
      LevelDefinitionValidationIssue(
        path: path,
        code: 'invalid_$field',
        message: '$fieldPrefix.$field must be >= 0.',
      ),
    );
    return null;
  }
  return value;
}

int? _readRequiredInt(
  Map<String, Object?> map, {
  required String field,
  required List<LevelDefinitionValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final raw = map[field];
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw.isFinite && raw == raw.roundToDouble()) {
    return raw.toInt();
  }
  issues.add(
    LevelDefinitionValidationIssue(
      path: path,
      code: 'invalid_$field',
      message: '$fieldPrefix.$field must be an integer.',
    ),
  );
  return null;
}

double? _readRequiredFiniteDouble(
  Map<String, Object?> map, {
  required String field,
  required List<LevelDefinitionValidationIssue> issues,
  required String path,
  required String fieldPrefix,
}) {
  final raw = map[field];
  if (raw is num && raw.isFinite) {
    return raw.toDouble();
  }
  issues.add(
    LevelDefinitionValidationIssue(
      path: path,
      code: 'invalid_$field',
      message: '$fieldPrefix.$field must be a finite number.',
    ),
  );
  return null;
}

double _normalizeZero(double value) {
  if (value == 0) {
    return 0;
  }
  return value;
}

String _normalizeNewlines(String raw) {
  return raw.replaceAll('\r\n', '\n');
}

String _formatCanonicalNumber(double value) {
  final normalized = _normalizeZero(value);
  if ((normalized - normalized.roundToDouble()).abs() < 1e-9) {
    return normalized.round().toString();
  }
  final fixed = normalized.toStringAsFixed(6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatDartDouble(double value) {
  final normalized = _normalizeZero(value);
  if ((normalized - normalized.roundToDouble()).abs() < 1e-9) {
    return '${normalized.round()}.0';
  }
  final fixed = normalized.toStringAsFixed(6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '.0');
}

String _escape(String raw) {
  return raw.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
}

String _renderLevelUiStatus(String status) {
  switch (status) {
    case activeLevelStatus:
      return 'LevelUiStatus.active';
    case deprecatedLevelStatus:
      return 'LevelUiStatus.deprecated';
  }
  throw StateError('Unsupported level status "$status".');
}

class LevelDefsLoadResult {
  const LevelDefsLoadResult({required this.levels, required this.issues});

  final List<LevelDefinitionSource> levels;
  final List<LevelDefinitionValidationIssue> issues;

  LevelDefsLoadResult copyWith({
    List<LevelDefinitionSource>? levels,
    List<LevelDefinitionValidationIssue>? issues,
  }) {
    return LevelDefsLoadResult(
      levels: levels ?? this.levels,
      issues: issues ?? this.issues,
    );
  }
}

class LevelDefinitionSource {
  const LevelDefinitionSource({
    required this.levelId,
    required this.revision,
    required this.displayName,
    required this.themeId,
    required this.cameraCenterY,
    required this.groundTopY,
    required this.earlyPatternChunks,
    required this.easyPatternChunks,
    required this.normalPatternChunks,
    required this.noEnemyChunks,
    required this.enumOrdinal,
    required this.status,
  });

  final String levelId;
  final int revision;
  final String displayName;
  final String themeId;
  final double cameraCenterY;
  final double groundTopY;
  final int earlyPatternChunks;
  final int easyPatternChunks;
  final int normalPatternChunks;
  final int noEnemyChunks;
  final int enumOrdinal;
  final String status;
}

class LevelDefinitionValidationIssue
    implements Comparable<LevelDefinitionValidationIssue> {
  const LevelDefinitionValidationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  @override
  int compareTo(LevelDefinitionValidationIssue other) {
    final pathCompare = path.compareTo(other.path);
    if (pathCompare != 0) {
      return pathCompare;
    }
    final codeCompare = code.compareTo(other.code);
    if (codeCompare != 0) {
      return codeCompare;
    }
    return message.compareTo(other.message);
  }
}
