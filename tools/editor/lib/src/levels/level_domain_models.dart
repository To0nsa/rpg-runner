import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';

const int levelDefsSchemaVersion = 1;
const String levelDefsSourcePath = 'assets/authoring/level/level_defs.json';
const String levelStatusActive = 'active';
const String levelStatusDeprecated = 'deprecated';
const int defaultAssemblyMinChunkCount = 2;
const int defaultAssemblyMaxChunkCount = 5;
const String defaultAssemblyGroupId = 'default';
const String defaultLevelChunkThemeGroupId = defaultAssemblyGroupId;

const double defaultLevelCameraCenterY = 135.0;
const double defaultLevelGroundTopY = 224.0;
const int defaultEarlyPatternChunks = 3;
const int defaultEasyPatternChunks = 0;
const int defaultNormalPatternChunks = 0;
const int defaultNoEnemyChunks = 3;

final RegExp stableLevelIdentifierPattern = RegExp(r'^[a-z][a-z0-9_]*$');

@immutable
class LevelAssemblySegmentDef {
  const LevelAssemblySegmentDef({
    required this.segmentId,
    required this.groupId,
    required this.minChunkCount,
    required this.maxChunkCount,
    required this.requireDistinctChunks,
  });

  final String segmentId;
  final String groupId;
  final int minChunkCount;
  final int maxChunkCount;
  final bool requireDistinctChunks;

  LevelAssemblySegmentDef copyWith({
    String? segmentId,
    String? groupId,
    int? minChunkCount,
    int? maxChunkCount,
    bool? requireDistinctChunks,
  }) {
    return LevelAssemblySegmentDef(
      segmentId: segmentId ?? this.segmentId,
      groupId: groupId ?? this.groupId,
      minChunkCount: minChunkCount ?? this.minChunkCount,
      maxChunkCount: maxChunkCount ?? this.maxChunkCount,
      requireDistinctChunks:
          requireDistinctChunks ?? this.requireDistinctChunks,
    );
  }

  LevelAssemblySegmentDef normalized() {
    return LevelAssemblySegmentDef(
      segmentId: segmentId.trim(),
      groupId: groupId.trim(),
      minChunkCount: minChunkCount,
      maxChunkCount: maxChunkCount,
      requireDistinctChunks: requireDistinctChunks,
    );
  }

  Map<String, Object?> toJson() {
    final normalizedValue = normalized();
    return <String, Object?>{
      'segmentId': normalizedValue.segmentId,
      'groupId': normalizedValue.groupId,
      'minChunkCount': normalizedValue.minChunkCount,
      'maxChunkCount': normalizedValue.maxChunkCount,
      'requireDistinctChunks': normalizedValue.requireDistinctChunks,
    };
  }
}

@immutable
class LevelAssemblyDef {
  const LevelAssemblyDef({
    this.loopSegments = true,
    this.segments = const <LevelAssemblySegmentDef>[],
  });

  final bool loopSegments;
  final List<LevelAssemblySegmentDef> segments;

  LevelAssemblyDef copyWith({
    bool? loopSegments,
    List<LevelAssemblySegmentDef>? segments,
  }) {
    return LevelAssemblyDef(
      loopSegments: loopSegments ?? this.loopSegments,
      segments: segments ?? this.segments,
    );
  }

  LevelAssemblyDef normalized() {
    return LevelAssemblyDef(
      loopSegments: loopSegments,
      segments: List<LevelAssemblySegmentDef>.unmodifiable(
        segments.map((segment) => segment.normalized()),
      ),
    );
  }

  Map<String, Object?> toJson() {
    final normalizedValue = normalized();
    return <String, Object?>{
      'loopSegments': normalizedValue.loopSegments,
      'segments': normalizedValue.segments
          .map((segment) => segment.toJson())
          .toList(growable: false),
    };
  }
}

@immutable
class LevelDef {
  const LevelDef({
    required this.levelId,
    required this.revision,
    required this.displayName,
    required this.visualThemeId,
    this.chunkThemeGroups = const <String>[defaultLevelChunkThemeGroupId],
    required this.cameraCenterY,
    required this.groundTopY,
    required this.earlyPatternChunks,
    required this.easyPatternChunks,
    required this.normalPatternChunks,
    required this.noEnemyChunks,
    required this.enumOrdinal,
    required this.status,
    this.assembly,
  });

  final String levelId;
  final int revision;
  final String displayName;
  final String visualThemeId;
  final List<String> chunkThemeGroups;
  final double cameraCenterY;
  final double groundTopY;
  final int earlyPatternChunks;
  final int easyPatternChunks;
  final int normalPatternChunks;
  final int noEnemyChunks;
  final int enumOrdinal;
  final String status;
  final LevelAssemblyDef? assembly;

  LevelDef copyWith({
    String? levelId,
    int? revision,
    String? displayName,
    String? visualThemeId,
    List<String>? chunkThemeGroups,
    double? cameraCenterY,
    double? groundTopY,
    int? earlyPatternChunks,
    int? easyPatternChunks,
    int? normalPatternChunks,
    int? noEnemyChunks,
    int? enumOrdinal,
    String? status,
    LevelAssemblyDef? assembly,
    bool clearAssembly = false,
  }) {
    return LevelDef(
      levelId: levelId ?? this.levelId,
      revision: revision ?? this.revision,
      displayName: displayName ?? this.displayName,
      visualThemeId: visualThemeId ?? this.visualThemeId,
      chunkThemeGroups: chunkThemeGroups ?? this.chunkThemeGroups,
      cameraCenterY: cameraCenterY ?? this.cameraCenterY,
      groundTopY: groundTopY ?? this.groundTopY,
      earlyPatternChunks: earlyPatternChunks ?? this.earlyPatternChunks,
      easyPatternChunks: easyPatternChunks ?? this.easyPatternChunks,
      normalPatternChunks: normalPatternChunks ?? this.normalPatternChunks,
      noEnemyChunks: noEnemyChunks ?? this.noEnemyChunks,
      enumOrdinal: enumOrdinal ?? this.enumOrdinal,
      status: status ?? this.status,
      assembly: clearAssembly ? null : (assembly ?? this.assembly),
    );
  }

  LevelDef normalized() {
    final normalizedAssembly = assembly?.normalized();
    return LevelDef(
      levelId: levelId.trim(),
      revision: revision,
      displayName: displayName.trim(),
      visualThemeId: visualThemeId.trim(),
      chunkThemeGroups: normalizeLevelChunkThemeGroups(chunkThemeGroups),
      cameraCenterY: normalizeLevelNumber(cameraCenterY),
      groundTopY: normalizeLevelNumber(groundTopY),
      earlyPatternChunks: earlyPatternChunks,
      easyPatternChunks: easyPatternChunks,
      normalPatternChunks: normalPatternChunks,
      noEnemyChunks: noEnemyChunks,
      enumOrdinal: enumOrdinal,
      status: status.trim(),
      assembly:
          normalizedAssembly == null || normalizedAssembly.segments.isEmpty
          ? null
          : normalizedAssembly,
    );
  }
}

@immutable
class LevelSourceBaseline {
  const LevelSourceBaseline({
    required this.sourcePath,
    required this.fingerprint,
  });

  final String sourcePath;
  final String fingerprint;
}

class LevelDefsDocument extends AuthoringDocument {
  const LevelDefsDocument({
    required this.workspaceRootPath,
    required this.levels,
    required this.baseline,
    required this.baselineLevels,
    required this.activeLevelId,
    required this.availableParallaxVisualThemeIds,
    required this.parallaxThemeSourceAvailable,
    required this.authoredChunkCountsByLevelId,
    required this.authoredChunkAssemblyGroupCountsByLevelId,
    required this.chunkCountSourceAvailable,
    this.loadIssues = const <ValidationIssue>[],
    this.operationIssues = const <ValidationIssue>[],
  });

  final String workspaceRootPath;
  final List<LevelDef> levels;
  final LevelSourceBaseline? baseline;
  final List<LevelDef> baselineLevels;
  final String? activeLevelId;
  final List<String> availableParallaxVisualThemeIds;
  final bool parallaxThemeSourceAvailable;
  final Map<String, int> authoredChunkCountsByLevelId;
  final Map<String, Map<String, int>> authoredChunkAssemblyGroupCountsByLevelId;
  final bool chunkCountSourceAvailable;
  final List<ValidationIssue> loadIssues;
  final List<ValidationIssue> operationIssues;

  LevelDefsDocument copyWith({
    String? workspaceRootPath,
    List<LevelDef>? levels,
    LevelSourceBaseline? baseline,
    bool clearBaseline = false,
    List<LevelDef>? baselineLevels,
    String? activeLevelId,
    bool clearActiveLevelId = false,
    List<String>? availableParallaxVisualThemeIds,
    bool? parallaxThemeSourceAvailable,
    Map<String, int>? authoredChunkCountsByLevelId,
    Map<String, Map<String, int>>? authoredChunkAssemblyGroupCountsByLevelId,
    bool? chunkCountSourceAvailable,
    List<ValidationIssue>? loadIssues,
    List<ValidationIssue>? operationIssues,
    bool clearOperationIssues = false,
  }) {
    return LevelDefsDocument(
      workspaceRootPath: workspaceRootPath ?? this.workspaceRootPath,
      levels: levels ?? this.levels,
      baseline: clearBaseline ? null : (baseline ?? this.baseline),
      baselineLevels: baselineLevels ?? this.baselineLevels,
      activeLevelId: clearActiveLevelId
          ? null
          : (activeLevelId ?? this.activeLevelId),
      availableParallaxVisualThemeIds:
          availableParallaxVisualThemeIds ??
          this.availableParallaxVisualThemeIds,
      parallaxThemeSourceAvailable:
          parallaxThemeSourceAvailable ?? this.parallaxThemeSourceAvailable,
      authoredChunkCountsByLevelId:
          authoredChunkCountsByLevelId ?? this.authoredChunkCountsByLevelId,
      authoredChunkAssemblyGroupCountsByLevelId:
          authoredChunkAssemblyGroupCountsByLevelId ??
          this.authoredChunkAssemblyGroupCountsByLevelId,
      chunkCountSourceAvailable:
          chunkCountSourceAvailable ?? this.chunkCountSourceAvailable,
      loadIssues: loadIssues ?? this.loadIssues,
      operationIssues: clearOperationIssues
          ? const <ValidationIssue>[]
          : (operationIssues ?? this.operationIssues),
    );
  }
}

class LevelScene extends EditableScene {
  const LevelScene({
    required this.levels,
    required this.activeLevelId,
    required this.activeLevel,
    required this.availableParallaxVisualThemeIds,
    required this.authoredChunkCountsByLevelId,
    required this.authoredChunkAssemblyGroupCountsByLevelId,
    required this.sourcePath,
    required this.workspaceRootPath,
  });

  final List<LevelDef> levels;
  final String? activeLevelId;
  final LevelDef? activeLevel;
  final List<String> availableParallaxVisualThemeIds;
  final Map<String, int> authoredChunkCountsByLevelId;
  final Map<String, Map<String, int>> authoredChunkAssemblyGroupCountsByLevelId;
  final String sourcePath;
  final String workspaceRootPath;
}

LevelDef? findLevelDefById(Iterable<LevelDef> levels, String? levelId) {
  if (levelId == null || levelId.isEmpty) {
    return null;
  }
  for (final level in levels) {
    if (level.levelId == levelId) {
      return level;
    }
  }
  return null;
}

int compareLevelDefsCanonical(LevelDef a, LevelDef b) {
  return a.levelId.compareTo(b.levelId);
}

int compareLevelDefsForScene(LevelDef a, LevelDef b) {
  final ordinalCompare = a.enumOrdinal.compareTo(b.enumOrdinal);
  if (ordinalCompare != 0) {
    return ordinalCompare;
  }
  return a.levelId.compareTo(b.levelId);
}

double normalizeLevelNumber(double value) {
  if (value == 0) {
    return 0;
  }
  return value;
}

String formatCanonicalLevelNumber(double value) {
  final normalized = normalizeLevelNumber(value);
  if ((normalized - normalized.roundToDouble()).abs() < 1e-9) {
    return normalized.round().toString();
  }
  final fixed = normalized.toStringAsFixed(6);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String renderCanonicalLevelDefsJson(Iterable<LevelDef> levels) {
  final sortedLevels = List<LevelDef>.from(
    levels.map((level) => level.normalized()),
  )..sort(compareLevelDefsCanonical);
  final buffer = StringBuffer()..writeln('{');
  buffer.writeln('  "schemaVersion": $levelDefsSchemaVersion,');
  buffer.writeln('  "levels": [');
  for (var i = 0; i < sortedLevels.length; i += 1) {
    final level = sortedLevels[i];
    buffer.writeln('    {');
    buffer.writeln('      "levelId": ${_quoted(level.levelId)},');
    buffer.writeln('      "revision": ${level.revision},');
    buffer.writeln('      "displayName": ${_quoted(level.displayName)},');
    buffer.writeln('      "visualThemeId": ${_quoted(level.visualThemeId)},');
    buffer.writeln(
      '      "chunkThemeGroups": ${_renderStringList(level.chunkThemeGroups)},',
    );
    buffer.writeln(
      '      "cameraCenterY": ${formatCanonicalLevelNumber(level.cameraCenterY)},',
    );
    buffer.writeln(
      '      "groundTopY": ${formatCanonicalLevelNumber(level.groundTopY)},',
    );
    buffer.writeln('      "earlyPatternChunks": ${level.earlyPatternChunks},');
    buffer.writeln('      "easyPatternChunks": ${level.easyPatternChunks},');
    buffer.writeln(
      '      "normalPatternChunks": ${level.normalPatternChunks},',
    );
    buffer.writeln('      "noEnemyChunks": ${level.noEnemyChunks},');
    buffer.writeln('      "enumOrdinal": ${level.enumOrdinal},');
    if (level.assembly == null) {
      buffer.writeln('      "status": ${_quoted(level.status)}');
    } else {
      buffer.writeln('      "status": ${_quoted(level.status)},');
      _writeAssembly(buffer, level.assembly!);
    }
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

bool levelDefEquals(LevelDef a, LevelDef b, {bool ignoreRevision = false}) {
  final left = a.normalized();
  final right = b.normalized();
  return left.levelId == right.levelId &&
      (ignoreRevision || left.revision == right.revision) &&
      left.displayName == right.displayName &&
      left.visualThemeId == right.visualThemeId &&
      _stringListsEqual(left.chunkThemeGroups, right.chunkThemeGroups) &&
      left.cameraCenterY == right.cameraCenterY &&
      left.groundTopY == right.groundTopY &&
      left.earlyPatternChunks == right.earlyPatternChunks &&
      left.easyPatternChunks == right.easyPatternChunks &&
      left.normalPatternChunks == right.normalPatternChunks &&
      left.noEnemyChunks == right.noEnemyChunks &&
      left.enumOrdinal == right.enumOrdinal &&
      left.status == right.status &&
      levelAssemblyEquals(left.assembly, right.assembly);
}

bool levelAssemblyEquals(LevelAssemblyDef? a, LevelAssemblyDef? b) {
  final left = a?.normalized();
  final right = b?.normalized();
  if (left == null || right == null) {
    return left == right;
  }
  if (left.loopSegments != right.loopSegments ||
      left.segments.length != right.segments.length) {
    return false;
  }
  for (var i = 0; i < left.segments.length; i += 1) {
    if (!levelAssemblySegmentEquals(left.segments[i], right.segments[i])) {
      return false;
    }
  }
  return true;
}

bool levelAssemblySegmentEquals(
  LevelAssemblySegmentDef a,
  LevelAssemblySegmentDef b,
) {
  final left = a.normalized();
  final right = b.normalized();
  return left.segmentId == right.segmentId &&
      left.groupId == right.groupId &&
      left.minChunkCount == right.minChunkCount &&
      left.maxChunkCount == right.maxChunkCount &&
      left.requireDistinctChunks == right.requireDistinctChunks;
}

void _writeAssembly(StringBuffer buffer, LevelAssemblyDef assembly) {
  final normalizedAssembly = assembly.normalized();
  buffer.writeln('      "assembly": {');
  buffer.writeln('        "loopSegments": ${normalizedAssembly.loopSegments},');
  buffer.writeln('        "segments": [');
  for (var i = 0; i < normalizedAssembly.segments.length; i += 1) {
    final segment = normalizedAssembly.segments[i];
    buffer.writeln('          {');
    buffer.writeln('            "segmentId": ${_quoted(segment.segmentId)},');
    buffer.writeln('            "groupId": ${_quoted(segment.groupId)},');
    buffer.writeln('            "minChunkCount": ${segment.minChunkCount},');
    buffer.writeln('            "maxChunkCount": ${segment.maxChunkCount},');
    buffer.writeln(
      '            "requireDistinctChunks": ${segment.requireDistinctChunks}',
    );
    buffer.write('          }');
    if (i < normalizedAssembly.segments.length - 1) {
      buffer.write(',');
    }
    buffer.writeln();
  }
  buffer.writeln('        ]');
  buffer.writeln('      }');
}

String titleCaseLevelId(String levelId) {
  final words = levelId
      .split('_')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return levelId;
  }
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _quoted(String value) {
  final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return '"$escaped"';
}

String _renderStringList(List<String> values) {
  if (values.isEmpty) {
    return '[]';
  }
  return '[${values.map(_quoted).join(', ')}]';
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

List<String> normalizeLevelChunkThemeGroups(Iterable<String> rawGroups) {
  final unique = <String>{};
  for (final rawGroup in rawGroups) {
    final normalized = rawGroup.trim();
    if (normalized.isEmpty) {
      continue;
    }
    unique.add(normalized);
  }
  final sorted = unique.toList(growable: false)..sort();
  if (sorted.contains(defaultLevelChunkThemeGroupId)) {
    final withoutDefault = sorted
        .where((groupId) => groupId != defaultLevelChunkThemeGroupId)
        .toList(growable: false);
    return List<String>.unmodifiable(
      <String>[defaultLevelChunkThemeGroupId, ...withoutDefault],
    );
  }
  return List<String>.unmodifiable(
    <String>[defaultLevelChunkThemeGroupId, ...sorted],
  );
}

LevelAssemblySegmentDef buildSuggestedLevelAssemblySegment({
  required Iterable<LevelAssemblySegmentDef> existingSegments,
  required Iterable<String> availableGroupIds,
  String preferredGroupId = defaultAssemblyGroupId,
}) {
  final normalizedPreferredGroupId = preferredGroupId.trim();
  final normalizedGroups =
      availableGroupIds
          .map((groupId) => groupId.trim())
          .where((groupId) => groupId.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  final groupId = _selectPreferredGroupId(
    preferredIds: <String>[normalizedPreferredGroupId, defaultAssemblyGroupId],
    availableGroupIds: normalizedGroups,
    fallback: normalizedPreferredGroupId.isNotEmpty
        ? normalizedPreferredGroupId
        : defaultAssemblyGroupId,
  );
  final segmentSeed = groupId.isNotEmpty ? groupId : 'segment';
  return LevelAssemblySegmentDef(
    segmentId: allocateUniqueAssemblySegmentId(existingSegments, segmentSeed),
    groupId: groupId,
    minChunkCount: defaultAssemblyMinChunkCount,
    maxChunkCount: defaultAssemblyMaxChunkCount,
    requireDistinctChunks: true,
  ).normalized();
}

String allocateUniqueAssemblySegmentId(
  Iterable<LevelAssemblySegmentDef> existingSegments,
  String preferredSeed,
) {
  final existingIds = existingSegments
      .map((segment) => segment.segmentId.trim())
      .where((segmentId) => segmentId.isNotEmpty)
      .toSet();
  final normalizedBase = slugifyStableIdentifier(
    preferredSeed,
    fallback: 'segment',
  );
  if (!existingIds.contains(normalizedBase)) {
    return normalizedBase;
  }
  var counter = 2;
  while (true) {
    final candidate = '${normalizedBase}_$counter';
    if (!existingIds.contains(candidate)) {
      return candidate;
    }
    counter += 1;
  }
}

String slugifyStableIdentifier(String raw, {required String fallback}) {
  final lower = raw.toLowerCase().trim();
  if (lower.isEmpty) {
    return fallback;
  }
  final normalized = lower.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  final collapsed = normalized
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (collapsed.isEmpty) {
    return fallback;
  }
  if (!RegExp(r'^[a-z]').hasMatch(collapsed)) {
    return '${fallback}_$collapsed';
  }
  return collapsed;
}

String _selectPreferredGroupId({
  required List<String> preferredIds,
  required List<String> availableGroupIds,
  required String fallback,
}) {
  for (final preferredId in preferredIds) {
    if (preferredId.isNotEmpty && availableGroupIds.contains(preferredId)) {
      return preferredId;
    }
  }
  if (availableGroupIds.isNotEmpty) {
    return availableGroupIds.first;
  }
  return fallback;
}
