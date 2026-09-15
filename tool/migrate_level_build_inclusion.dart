import 'dart:convert';
import 'dart:io';

import 'generated_artifact_plan.dart';
import 'level_definition_generation.dart';

const String _sourcePath = 'assets/authoring/level/level_defs.json';

/// Explicit canonical Level v1/v2-to-v3 migration preserving authored geometry.
///
/// Identity, ordinal, revision, status and design values are unchanged. Invalid
/// or noncanonical legacy input is rejected, and valid current input is a no-op.
String migrateLevelBuildInclusionSource(
  String raw, {
  required String sourcePath,
}) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Level source must be an object.');
  }
  if (decoded['schemaVersion'] == levelDefsSchemaVersion) {
    _requireValid(decodeLevelDefinitions(raw, defsPath: sourcePath));
    return raw;
  }
  final legacyVersion = decoded['schemaVersion'];
  if ((legacyVersion != 1 && legacyVersion != 2) ||
      decoded['levels'] is! List<Object?>) {
    throw const FormatException(
      'Migration requires canonical Level schema v1 or v2.',
    );
  }
  final migrated = <String, Object?>{
    ...decoded,
    'schemaVersion': levelDefsSchemaVersion,
    'levels': <Map<String, Object?>>[
      for (final entry in decoded['levels'] as List<Object?>)
        if (entry is Map<String, Object?> &&
            !entry.containsKey('terrainHeightStepPx') &&
            (legacyVersion != 1 || !entry.containsKey('includeInBuild')))
          <String, Object?>{
            ...entry,
            if (legacyVersion == 1) 'includeInBuild': true,
            'terrainHeightStepPx': 24,
          }
        else
          throw const FormatException('Invalid legacy Level record.'),
    ],
  };
  final parsed = decodeLevelDefinitions(
    jsonEncode(migrated),
    defsPath: sourcePath,
  );
  _requireValid(parsed, allowNoncanonical: true);
  final canonical = renderCanonicalLevelDefsJson(parsed.levels);
  var legacyCanonical = canonical
      .replaceFirst(
        '"schemaVersion": $levelDefsSchemaVersion',
        '"schemaVersion": $legacyVersion',
      )
      .replaceAll('      "terrainHeightStepPx": 24,\n', '');
  if (legacyVersion == 1) {
    legacyCanonical = legacyCanonical.replaceAll(
      '      "includeInBuild": true,\n',
      '',
    );
  }
  if (raw.replaceAll('\r\n', '\n') != legacyCanonical) {
    throw const FormatException(
      'Legacy Level source must be canonical before migration.',
    );
  }
  _requireValid(decodeLevelDefinitions(canonical, defsPath: sourcePath));
  return canonical;
}

void _requireValid(
  LevelDefsLoadResult result, {
  bool allowNoncanonical = false,
}) {
  final issues = result.issues
      .where(
        (issue) =>
            !allowNoncanonical || issue.code != 'non_canonical_level_defs',
      )
      .toList();
  if (issues.isNotEmpty) {
    throw FormatException(
      issues.map((issue) => '${issue.code}: ${issue.message}').join('\n'),
    );
  }
}

/// The default mode previews migration. Only --apply replaces the source file.
Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--apply' && arg != '--check')) {
    stderr.writeln(
      'Usage: dart run tool/migrate_level_build_inclusion.dart [--check|--apply]',
    );
    exitCode = 64;
    return;
  }
  try {
    final source = File(_sourcePath);
    final before = await source.readAsString();
    final after = migrateLevelBuildInclusionSource(
      before,
      sourcePath: _sourcePath,
    );
    if (before == after) {
      stdout.writeln('Level source already uses canonical schema v3.');
      return;
    }
    if (!args.contains('--apply')) {
      stdout.writeln(
        'Level migration is valid; --apply adds the three elevation presets and preserves existing records.',
      );
      return;
    }
    if (await source.readAsString() != before) {
      throw StateError('Level source changed during migration planning.');
    }
    await GeneratedArtifactPlan(<GeneratedArtifact>[
      GeneratedArtifact(path: _sourcePath, content: after),
    ]).writeAll();
    stdout.writeln(
      'Migrated Level source to schema v3; existing terrain and inclusion remain unchanged.',
    );
  } on Object catch (error) {
    stderr.writeln('Level inclusion migration failed: $error');
    exitCode = 1;
  }
}
