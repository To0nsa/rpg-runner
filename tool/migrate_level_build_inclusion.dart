import 'dart:convert';
import 'dart:io';

import 'generated_artifact_plan.dart';
import 'level_definition_generation.dart';

const String _sourcePath = 'assets/authoring/level/level_defs.json';

/// Explicit canonical v1-to-v2 migration; every existing identity stays included.
///
/// Identity, ordinal, revision, status and design values are unchanged. Invalid
/// or noncanonical legacy input is rejected, and valid v2 input is a no-op.
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
  if (decoded['schemaVersion'] != 1 || decoded['levels'] is! List<Object?>) {
    throw const FormatException(
      'Migration requires canonical Level schema v1.',
    );
  }
  final migrated = <String, Object?>{
    ...decoded,
    'schemaVersion': levelDefsSchemaVersion,
    'levels': <Map<String, Object?>>[
      for (final entry in decoded['levels'] as List<Object?>)
        if (entry is Map<String, Object?> &&
            !entry.containsKey('includeInBuild'))
          <String, Object?>{...entry, 'includeInBuild': true}
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
  final legacyCanonical = canonical
      .replaceFirst('"schemaVersion": 2', '"schemaVersion": 1')
      .replaceAll('      "includeInBuild": true,\n', '');
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
      stdout.writeln('Level source already uses canonical schema v2.');
      return;
    }
    if (!args.contains('--apply')) {
      stdout.writeln(
        'Level schema v1 migration is valid; --apply preserves all records with includeInBuild=true.',
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
      'Migrated Level source to schema v2; all existing records remain included.',
    );
  } on Object catch (error) {
    stderr.writeln('Level inclusion migration failed: $error');
    exitCode = 1;
  }
}
