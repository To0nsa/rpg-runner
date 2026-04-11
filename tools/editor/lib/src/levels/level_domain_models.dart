import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';

const int levelDefsSchemaVersion = 1;
const String levelDefsSourcePath = 'assets/authoring/level/level_defs.json';
const String levelStatusActive = 'active';
const String levelStatusDeprecated = 'deprecated';

const double defaultLevelCameraCenterY = 135.0;
const double defaultLevelGroundTopY = 224.0;
const int defaultEarlyPatternChunks = 3;
const int defaultEasyPatternChunks = 0;
const int defaultNormalPatternChunks = 0;
const int defaultNoEnemyChunks = 3;

final RegExp stableLevelIdentifierPattern = RegExp(r'^[a-z][a-z0-9_]*$');

@immutable
class LevelDef {
  const LevelDef({
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

  LevelDef copyWith({
    String? levelId,
    int? revision,
    String? displayName,
    String? themeId,
    double? cameraCenterY,
    double? groundTopY,
    int? earlyPatternChunks,
    int? easyPatternChunks,
    int? normalPatternChunks,
    int? noEnemyChunks,
    int? enumOrdinal,
    String? status,
  }) {
    return LevelDef(
      levelId: levelId ?? this.levelId,
      revision: revision ?? this.revision,
      displayName: displayName ?? this.displayName,
      themeId: themeId ?? this.themeId,
      cameraCenterY: cameraCenterY ?? this.cameraCenterY,
      groundTopY: groundTopY ?? this.groundTopY,
      earlyPatternChunks: earlyPatternChunks ?? this.earlyPatternChunks,
      easyPatternChunks: easyPatternChunks ?? this.easyPatternChunks,
      normalPatternChunks: normalPatternChunks ?? this.normalPatternChunks,
      noEnemyChunks: noEnemyChunks ?? this.noEnemyChunks,
      enumOrdinal: enumOrdinal ?? this.enumOrdinal,
      status: status ?? this.status,
    );
  }

  LevelDef normalized() {
    return LevelDef(
      levelId: levelId.trim(),
      revision: revision,
      displayName: displayName.trim(),
      themeId: themeId.trim(),
      cameraCenterY: normalizeLevelNumber(cameraCenterY),
      groundTopY: normalizeLevelNumber(groundTopY),
      earlyPatternChunks: earlyPatternChunks,
      easyPatternChunks: easyPatternChunks,
      normalPatternChunks: normalPatternChunks,
      noEnemyChunks: noEnemyChunks,
      enumOrdinal: enumOrdinal,
      status: status.trim(),
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
    required this.availableParallaxThemeIds,
    required this.parallaxThemeSourceAvailable,
    required this.authoredChunkCountsByLevelId,
    required this.chunkCountSourceAvailable,
    this.loadIssues = const <ValidationIssue>[],
    this.operationIssues = const <ValidationIssue>[],
  });

  final String workspaceRootPath;
  final List<LevelDef> levels;
  final LevelSourceBaseline? baseline;
  final List<LevelDef> baselineLevels;
  final String? activeLevelId;
  final List<String> availableParallaxThemeIds;
  final bool parallaxThemeSourceAvailable;
  final Map<String, int> authoredChunkCountsByLevelId;
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
    List<String>? availableParallaxThemeIds,
    bool? parallaxThemeSourceAvailable,
    Map<String, int>? authoredChunkCountsByLevelId,
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
      availableParallaxThemeIds:
          availableParallaxThemeIds ?? this.availableParallaxThemeIds,
      parallaxThemeSourceAvailable:
          parallaxThemeSourceAvailable ?? this.parallaxThemeSourceAvailable,
      authoredChunkCountsByLevelId:
          authoredChunkCountsByLevelId ?? this.authoredChunkCountsByLevelId,
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
    required this.availableParallaxThemeIds,
    required this.authoredChunkCountsByLevelId,
    required this.sourcePath,
    required this.workspaceRootPath,
  });

  final List<LevelDef> levels;
  final String? activeLevelId;
  final LevelDef? activeLevel;
  final List<String> availableParallaxThemeIds;
  final Map<String, int> authoredChunkCountsByLevelId;
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
    buffer.writeln('      "themeId": ${_quoted(level.themeId)},');
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
    buffer.writeln('      "status": ${_quoted(level.status)}');
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
      left.themeId == right.themeId &&
      left.cameraCenterY == right.cameraCenterY &&
      left.groundTopY == right.groundTopY &&
      left.earlyPatternChunks == right.earlyPatternChunks &&
      left.easyPatternChunks == right.easyPatternChunks &&
      left.normalPatternChunks == right.normalPatternChunks &&
      left.noEnemyChunks == right.noEnemyChunks &&
      left.enumOrdinal == right.enumOrdinal &&
      left.status == right.status;
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
