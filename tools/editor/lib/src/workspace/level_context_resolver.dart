import 'dart:convert';
import 'dart:io';

import 'editor_workspace.dart';

const String defaultLevelDefsPath = 'assets/authoring/level/level_defs.json';
const String defaultLevelIdSourcePath =
    'packages/runner_core/lib/levels/level_id.dart';
const String defaultLevelRegistrySourcePath =
    'packages/runner_core/lib/levels/level_registry.dart';

/// Deterministic level option source resolved for an editor workflow.
class LevelOptionResolution {
  const LevelOptionResolution({required this.options, required this.source});

  final List<String> options;
  final String source;
}

LevelOptionResolution resolveLevelOptions(
  EditorWorkspace workspace, {
  Set<String> discoveredLevelIds = const <String>{},
}) {
  final fromLevelDefs = _extractLevelOptionsFromLevelDefs(workspace);
  if (fromLevelDefs.isNotEmpty) {
    return LevelOptionResolution(
      options: fromLevelDefs,
      source: 'level_defs_json',
    );
  }

  final fromEnum = _extractLevelOptionsFromLevelEnum(workspace);
  if (fromEnum.isNotEmpty) {
    return LevelOptionResolution(
      options: fromEnum,
      source: 'core_level_id_enum',
    );
  }

  final fallback = discoveredLevelIds.toList(growable: false)..sort();
  return LevelOptionResolution(
    options: fallback,
    source: 'discovered_chunk_level_ids',
  );
}

String? resolveActiveLevelId({
  required List<String> options,
  required String? preferredLevelId,
}) {
  if (options.isEmpty) {
    return null;
  }
  if (preferredLevelId != null && options.contains(preferredLevelId)) {
    return preferredLevelId;
  }
  return options.first;
}

Map<String, String> extractLevelThemeIds(
  EditorWorkspace workspace, {
  String levelRegistryPath = defaultLevelRegistrySourcePath,
}) {
  final file = File(workspace.resolve(levelRegistryPath));
  if (!file.existsSync()) {
    return const <String, String>{};
  }

  final source = file.readAsStringSync();
  final mapping = <String, String>{};
  final casePattern = RegExp(
    r"case\s+LevelId\.(\w+)\s*:\s*return\s+LevelDefinition\([\s\S]*?themeId:\s*'([^']+)'",
    multiLine: true,
  );
  for (final match in casePattern.allMatches(source)) {
    final levelId = match.group(1)?.trim() ?? '';
    final themeId = match.group(2)?.trim() ?? '';
    if (levelId.isEmpty || themeId.isEmpty) {
      continue;
    }
    mapping[levelId] = themeId;
  }

  final sortedEntries = mapping.entries.toList(growable: false)
    ..sort((a, b) => a.key.compareTo(b.key));
  return Map<String, String>.unmodifiable(
    <String, String>{for (final entry in sortedEntries) entry.key: entry.value},
  );
}

List<String> _extractLevelOptionsFromLevelDefs(EditorWorkspace workspace) {
  final file = File(workspace.resolve(defaultLevelDefsPath));
  if (!file.existsSync()) {
    return const <String>[];
  }
  final map = _parseJsonMap(file.readAsStringSync());
  if (map == null) {
    return const <String>[];
  }

  final levelIds = <String>{};
  final rawLevels = map['levels'];
  if (rawLevels is List<Object?>) {
    for (final value in rawLevels) {
      if (value is! Map<String, Object?>) {
        continue;
      }
      final id = _normalizedString(value['id']);
      if (id.isNotEmpty) {
        levelIds.add(id);
      }
    }
  }

  final rawLevelIds = map['levelIds'];
  if (rawLevelIds is List<Object?>) {
    for (final value in rawLevelIds) {
      final id = _normalizedString(value);
      if (id.isNotEmpty) {
        levelIds.add(id);
      }
    }
  }

  final options = levelIds.toList(growable: false)..sort();
  return List<String>.unmodifiable(options);
}

List<String> _extractLevelOptionsFromLevelEnum(EditorWorkspace workspace) {
  final file = File(workspace.resolve(defaultLevelIdSourcePath));
  if (!file.existsSync()) {
    return const <String>[];
  }
  final source = file.readAsStringSync();
  final enumMatch = RegExp(
    r'enum\s+LevelId\s*\{([^}]*)\}',
    dotAll: true,
  ).firstMatch(source);
  if (enumMatch == null) {
    return const <String>[];
  }
  final enumBody = enumMatch.group(1) ?? '';
  final values =
      enumBody
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .where((value) => !value.startsWith('//'))
          .map((value) => value.split(' ').first.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  return List<String>.unmodifiable(values);
}

Map<String, Object?>? _parseJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
  } on Object {
    return null;
  }
  return null;
}

String _normalizedString(Object? raw) {
  if (raw is String) {
    return raw.trim();
  }
  return '';
}
