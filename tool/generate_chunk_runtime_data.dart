import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import 'generated_artifact_plan.dart';
import 'level_definition_generation.dart';
import 'parallax_theme_generation.dart';
import 'polygon_terrain_render.dart';
import 'terrain_material_generation.dart';

const String _chunksDirectoryPath = 'assets/authoring/level/chunks';
const String _levelDefsPath = 'assets/authoring/level/level_defs.json';
const String _parallaxDefsPath = 'assets/authoring/level/parallax_defs.json';
const String _prefabDefsPath = 'assets/authoring/level/prefab_defs.json';
const String _tileDefsPath = 'assets/authoring/level/tile_defs.json';
const String _outputPath =
    'packages/runner_core/lib/track/authored_chunk_patterns.dart';
const String _levelIdOutputPath =
    'packages/runner_core/lib/levels/level_id.dart';
const String _levelRegistryOutputPath =
    'packages/runner_core/lib/levels/level_registry.dart';
const String _levelUiMetadataOutputPath =
    'lib/ui/levels/generated_level_ui_metadata.dart';
const String _parallaxOutputPath =
    'lib/game/themes/authored_parallax_themes.dart';
const List<String> _difficultyOrder = <String>[
  'early',
  'easy',
  'normal',
  'hard',
];

Future<void> main(List<String> args) async {
  final showHelp = args.contains('-h') || args.contains('--help');
  if (showHelp) {
    _printUsage();
    return;
  }

  final unknownArgs = args.where((arg) => arg != '--dry-run').toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknownArgs.join(', ')}');
    _printUsage();
    exitCode = 64;
    return;
  }

  final dryRun = args.contains('--dry-run');

  try {
    final issues = <_ValidationIssue>[];
    final identities = <_ChunkIdentity>[];
    final authoredChunks = <_ChunkExportData>[];
    final files = await _listChunkJsonFiles();
    final levelResult = await loadLevelDefinitions(defsPath: _levelDefsPath);
    final parallaxResult = await loadParallaxThemes(
      defsPath: _parallaxDefsPath,
    );
    final terrainMaterialResult = await buildTerrainMaterialRegistry();
    final prefabContents = await _readRequiredText(_prefabDefsPath, issues);
    final tileContents = await _readRequiredText(_tileDefsPath, issues);
    PolygonTerrainPrefabSourceSet? runtimePrefabs;
    PolygonTileSourceSet? runtimeTiles;
    if (prefabContents != null) {
      try {
        runtimePrefabs = decodePolygonTerrainPrefabs(
          prefabContents,
          sourcePath: _prefabDefsPath,
        );
      } on FormatException {
        // Repository terrain generation reports the canonical prefab issue.
      }
    }
    if (tileContents != null) {
      try {
        runtimeTiles = decodePolygonTileSources(
          tileContents,
          sourcePath: _tileDefsPath,
        );
      } on FormatException catch (error) {
        issues.add(
          _ValidationIssue(
            path: _tileDefsPath,
            code: 'tile_source_invalid',
            message: error.message.toString(),
          ),
        );
      }
    }
    final chunkContentsByPath = <String, String>{};
    for (final file in files) {
      final path = _toRepoRelativePath(file.path);
      final contents = await _readRequiredText(path, issues);
      if (contents != null) chunkContentsByPath[path] = contents;
    }

    issues.addAll(
      levelResult.issues.map(
        (issue) => _ValidationIssue(
          path: issue.path,
          code: issue.code,
          message: issue.message,
        ),
      ),
    );
    issues.addAll(
      parallaxResult.issues.map(
        (issue) => _ValidationIssue(
          path: issue.path,
          code: issue.code,
          message: issue.message,
        ),
      ),
    );
    issues.addAll(
      terrainMaterialResult.issues.map(
        (issue) => _ValidationIssue(
          path: issue.path,
          code: issue.code,
          message: issue.message,
        ),
      ),
    );

    if (files.isEmpty) {
      stdout.writeln('No chunk json files found under $_chunksDirectoryPath.');
    }

    PolygonTerrainRepositoryGenerationResult? terrainResult;
    if (prefabContents != null && chunkContentsByPath.length == files.length) {
      terrainResult = buildPolygonTerrainRepository(
        prefabSourcePath: _prefabDefsPath,
        prefabContents: prefabContents,
        chunkInputs: chunkContentsByPath.entries.map(
          (entry) => PolygonTerrainRepositoryChunkInput(
            sourcePath: entry.key,
            contents: entry.value,
          ),
        ),
        levels: levelResult.levels.map(_terrainSchedulerLevel),
        schedulerSourcePath: _levelDefsPath,
      );
      issues.addAll(
        terrainResult.issues.map(
          (issue) => _ValidationIssue(
            path: issue.sourcePath,
            code: issue.code,
            message: issue.message,
          ),
        ),
      );
      for (final chunk in terrainResult.chunks) {
        identities.add(
          _ChunkIdentity(
            path: chunk.sourcePath,
            levelId: chunk.source.levelId,
            chunkKey: chunk.source.chunkKey,
            id: chunk.source.id,
          ),
        );
        _validateLevelOwnershipPath(
          path: chunk.sourcePath,
          levelId: chunk.source.levelId,
          issues: issues,
        );
        if (runtimePrefabs == null || runtimeTiles == null) continue;
        final materialized = materializePolygonTerrainRuntimeChunk(
          sourcePath: chunk.sourcePath,
          compiled: chunk.compiled,
          prefabSources: runtimePrefabs,
          tileSources: runtimeTiles,
        );
        issues.addAll(
          materialized.issues.map(
            (issue) => _ValidationIssue(
              path: issue.sourcePath,
              code: issue.code,
              message: issue.message,
            ),
          ),
        );
        if (materialized.chunk case final runtimeChunk?) {
          authoredChunks.add(
            _ChunkExportData(
              path: chunk.sourcePath,
              levelId: chunk.source.levelId,
              difficulty: chunk.source.difficulty,
              pattern: runtimeChunk.pattern,
            ),
          );
        }
      }
      if (terrainMaterialResult.catalog case final materialCatalog?) {
        _validateTerrainMaterialReferences(
          terrainResult,
          materialKeys: materialCatalog.byKey.keys.toSet(),
          issues: issues,
        );
      }
    }

    _collectDuplicateIdentityIssues(
      identities,
      issues,
      fieldName: 'chunkKey',
      issueCode: 'duplicate_chunk_key',
      selector: (identity) => identity.chunkKey,
    );
    _collectDuplicateIdentityIssues(
      identities,
      issues,
      fieldName: 'id',
      issueCode: 'duplicate_chunk_id',
      selector: (identity) => identity.id,
    );
    _validateChunkGroupsAgainstLevels(
      levels: levelResult.levels,
      authoredChunks: authoredChunks,
      issues: issues,
    );
    _validateLevelAssemblyAgainstChunks(
      levels: levelResult.levels,
      authoredChunks: authoredChunks,
      issues: issues,
    );
    _validateLevelVisualThemes(
      levels: levelResult.levels,
      authoredVisualThemeIds: parallaxResult.themes
          .map((theme) => theme.parallaxThemeId)
          .toSet(),
      issues: issues,
    );

    issues.sort();

    if (issues.isNotEmpty) {
      for (final issue in issues) {
        stderr.writeln('[ERROR] ${issue.code} ${issue.path}: ${issue.message}');
      }
      stderr.writeln(
        'Validation failed with ${issues.length} blocking issue(s).',
      );
      exitCode = 1;
      return;
    }

    stdout.writeln('Validated ${files.length} chunk json file(s).');
    stdout.writeln(
      'Validated ${levelResult.levels.length} level definition(s).',
    );
    stdout.writeln(
      'Validated ${parallaxResult.themes.length} parallax theme definition(s).',
    );
    stdout.writeln(
      'Validated ${terrainMaterialResult.catalog!.materials.length} terrain '
      'material definition(s).',
    );
    final levelIdOutput = renderLevelIdDartOutput(levelResult.levels);
    final levelRegistryOutput = renderLevelRegistryDartOutput(
      levelResult.levels,
    );
    final levelUiMetadataOutput = renderLevelUiMetadataDartOutput(
      levelResult.levels,
    );
    authoredChunks.sort(_compareChunkExportData);
    final output = _renderDartOutput(authoredChunks);
    final parallaxOutput = renderParallaxThemeDartOutput(parallaxResult.themes);
    final stagedTerrainOutput = buildStagedPolygonTerrainArtifact(
      batch: terrainResult!.validatedBatch!,
    );
    final artifactPlan = GeneratedArtifactPlan(
      <GeneratedArtifact>[
        GeneratedArtifact(path: _outputPath, content: output),
        GeneratedArtifact(path: _levelIdOutputPath, content: levelIdOutput),
        GeneratedArtifact(
          path: _levelRegistryOutputPath,
          content: levelRegistryOutput,
        ),
        GeneratedArtifact(
          path: _levelUiMetadataOutputPath,
          content: levelUiMetadataOutput,
        ),
        GeneratedArtifact(path: _parallaxOutputPath, content: parallaxOutput),
        terrainMaterialResult.output!,
        stagedTerrainOutput,
      ],
      ownershipMarker: 'Generated by tool/generate_chunk_runtime_data.dart',
      ownershipSearchRoots: const <String>['packages/runner_core/lib', 'lib'],
    );
    if (dryRun) {
      final drift = await artifactPlan.inspectDrift();
      if (drift.isNotEmpty) {
        for (final item in drift) {
          stderr.writeln('[ERROR] ${item.code} ${item.path}: ${item.message}');
        }
        stderr.writeln(
          'Generated output drift found in ${drift.length} file(s).',
        );
        exitCode = 1;
        return;
      }
      stdout.writeln('Dry-run completed with no blocking issues.');
      return;
    }
    await artifactPlan.writeAll();
    stdout.writeln(
      'Generated $_outputPath (${authoredChunks.length} chunk(s)).',
    );
    stdout.writeln(
      'Generated $_levelIdOutputPath (${levelResult.levels.length} level(s)).',
    );
    stdout.writeln(
      'Generated $_levelRegistryOutputPath '
      '(${levelResult.levels.length} level(s)).',
    );
    stdout.writeln(
      'Generated $_levelUiMetadataOutputPath '
      '(${levelResult.levels.length} level(s)).',
    );
    stdout.writeln(
      'Generated $_parallaxOutputPath '
      '(${parallaxResult.themes.length} theme(s)).',
    );
    stdout.writeln(
      'Generated ${terrainMaterialResult.output!.path} '
      '(${terrainMaterialResult.catalog!.materials.length} material(s)).',
    );
    stdout.writeln(
      'Generated ${stagedTerrainOutput.path} '
      '(${terrainResult.chunks.length} chunk(s), staged only).',
    );
  } on Object catch (error) {
    stderr.writeln('Chunk generation failed: $error');
    exitCode = 1;
  }
}

PolygonTerrainSchedulerLevelSource _terrainSchedulerLevel(
  LevelDefinitionSource level,
) => PolygonTerrainSchedulerLevelSource(
  levelId: level.levelId,
  earlyPatternChunks: level.earlyPatternChunks,
  easyPatternChunks: level.easyPatternChunks,
  normalPatternChunks: level.normalPatternChunks,
  assembly: level.assembly == null
      ? null
      : PolygonTerrainSchedulerAssemblySource(
          loopSegments: level.assembly!.loopSegments,
          segments: <PolygonTerrainSchedulerSegmentSource>[
            for (final segment in level.assembly!.segments)
              PolygonTerrainSchedulerSegmentSource(
                segmentId: segment.segmentId,
                groupId: segment.groupId,
                minChunkCount: segment.minChunkCount,
                maxChunkCount: segment.maxChunkCount,
                requireDistinctChunks: segment.requireDistinctChunks,
              ),
          ],
        ),
);

Future<List<File>> _listChunkJsonFiles() async {
  final directory = Directory(_chunksDirectoryPath);
  if (!await directory.exists()) {
    return const <File>[];
  }

  final files = <File>[];
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final path = _toRepoRelativePath(entity.path).toLowerCase();
    if (!path.endsWith('.json')) continue;
    files.add(entity);
  }

  files.sort(
    (a, b) =>
        _toRepoRelativePath(a.path).compareTo(_toRepoRelativePath(b.path)),
  );
  return files;
}

void _validateLevelOwnershipPath({
  required String path,
  required String levelId,
  required List<_ValidationIssue> issues,
}) {
  final pathLevelId = _levelIdFromChunkPath(path);
  if (pathLevelId == null) {
    issues.add(
      _ValidationIssue(
        path: path,
        code: 'invalid_chunk_path',
        message:
            'Chunk files must live under $_chunksDirectoryPath/<levelId>/...',
      ),
    );
    return;
  }
  if (levelId.isEmpty) {
    return;
  }
  if (pathLevelId != levelId) {
    issues.add(
      _ValidationIssue(
        path: path,
        code: 'level_id_path_mismatch',
        message:
            'levelId "$levelId" must match owning path level "$pathLevelId".',
      ),
    );
  }
}

String? _levelIdFromChunkPath(String path) {
  final normalized = _normalizePath(path);
  final prefix = '$_chunksDirectoryPath/';
  if (!normalized.startsWith(prefix)) {
    return null;
  }
  final remainder = normalized.substring(prefix.length);
  final segments = remainder.split('/');
  if (segments.length < 2 || segments.first.isEmpty) {
    return null;
  }
  return segments.first;
}

Future<String?> _readRequiredText(
  String relativePath,
  List<_ValidationIssue> issues,
) async {
  final file = File(relativePath);
  if (!await file.exists()) {
    issues.add(
      _ValidationIssue(
        path: relativePath,
        code: 'missing_file',
        message: 'Required file is missing.',
      ),
    );
    return null;
  }
  try {
    return await file.readAsString();
  } on Object catch (error) {
    issues.add(
      _ValidationIssue(
        path: relativePath,
        code: 'read_failed',
        message: 'Unable to read file: $error',
      ),
    );
    return null;
  }
}

int _compareChunkExportData(_ChunkExportData a, _ChunkExportData b) {
  final levelCompare = a.levelId.compareTo(b.levelId);
  if (levelCompare != 0) return levelCompare;
  final difficultyCompare = _difficultyIndex(
    a.difficulty,
  ).compareTo(_difficultyIndex(b.difficulty));
  if (difficultyCompare != 0) return difficultyCompare;
  final chunkKeyCompare = a.chunkKey.compareTo(b.chunkKey);
  if (chunkKeyCompare != 0) return chunkKeyCompare;
  return a.name.compareTo(b.name);
}

int _difficultyIndex(String difficulty) {
  final index = _difficultyOrder.indexOf(difficulty);
  if (index >= 0) {
    return index;
  }
  return _difficultyOrder.length;
}

String _renderDartOutput(List<_ChunkExportData> chunks) {
  final chunksByLevel = <String, Map<String, List<_ChunkExportData>>>{};
  for (final chunk in chunks) {
    final byDifficulty = chunksByLevel.putIfAbsent(
      chunk.levelId,
      () => <String, List<_ChunkExportData>>{},
    );
    byDifficulty
        .putIfAbsent(chunk.difficulty, () => <_ChunkExportData>[])
        .add(chunk);
  }

  final levelIds = chunksByLevel.keys.toList()..sort();
  final hasAnySpawnMarkers = chunks.any(
    (chunk) => chunk.spawnMarkers.isNotEmpty,
  );
  final buffer = StringBuffer()
    ..writeln('/// GENERATED FILE. DO NOT EDIT BY HAND.')
    ..writeln('///')
    ..writeln('/// Generated by tool/generate_chunk_runtime_data.dart from:')
    ..writeln('/// - `assets/authoring/level/chunks/<levelId>/**/*.json`')
    ..writeln('/// - assets/authoring/level/prefab_defs.json')
    ..writeln('/// - assets/authoring/level/tile_defs.json')
    ..writeln('library;')
    ..writeln();
  if (hasAnySpawnMarkers) {
    buffer.writeln("import '../enemies/enemy_id.dart';");
  }
  buffer
    ..writeln("import 'chunk_pattern.dart';")
    ..writeln("import 'chunk_pattern_source.dart';")
    ..writeln();

  for (final levelId in levelIds) {
    final byDifficulty = chunksByLevel[levelId]!;
    for (final difficulty in _difficultyOrder) {
      final tierChunks = byDifficulty[difficulty] ?? const <_ChunkExportData>[];
      _writePatternList(
        buffer,
        _patternsVariableName(levelId, difficulty),
        tierChunks,
      );
      buffer.writeln();
    }
  }

  buffer.writeln(
    'const Map<String, ChunkPatternListSource> authoredChunkPatternSourcesByLevel = <String, ChunkPatternListSource>{',
  );
  for (final levelId in levelIds) {
    buffer
      ..writeln("  '${_escape(levelId)}': ChunkPatternListSource(")
      ..writeln(
        '    earlyPatterns: ${_patternsVariableName(levelId, 'early')},',
      )
      ..writeln('    easyPatterns: ${_patternsVariableName(levelId, 'easy')},')
      ..writeln(
        '    normalPatterns: ${_patternsVariableName(levelId, 'normal')},',
      )
      ..writeln('    hardPatterns: ${_patternsVariableName(levelId, 'hard')},')
      ..writeln('  ),');
  }
  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('ChunkPatternListSource authoredChunkPatternSourceForLevel(')
    ..writeln('  String levelId,')
    ..writeln(') {')
    ..writeln('  final source = authoredChunkPatternSourcesByLevel[levelId];')
    ..writeln('  if (source != null) {')
    ..writeln('    return source;')
    ..writeln('  }')
    ..writeln(
      '  throw StateError(\'No authored chunk pattern source for levelId="\$levelId".\');',
    )
    ..writeln('}');

  return buffer.toString();
}

void _writePatternList(
  StringBuffer buffer,
  String variableName,
  List<_ChunkExportData> chunks,
) {
  buffer.writeln('const List<ChunkPattern> $variableName = <ChunkPattern>[');
  for (final chunk in chunks) {
    buffer
      ..writeln('  ChunkPattern(')
      ..writeln("    name: '${_escape(chunk.name)}',")
      ..writeln("    chunkKey: '${_escape(chunk.chunkKey)}',")
      ..writeln("    assemblyGroupId: '${_escape(chunk.assemblyGroupId)}',");

    buffer.writeln('    visualSprites: <ChunkVisualSpriteRel>[');
    for (final sprite in chunk.visualSprites) {
      buffer
        ..writeln('      ChunkVisualSpriteRel(')
        ..writeln("        assetPath: '${_escape(sprite.assetPath)}',")
        ..writeln('        srcX: ${sprite.srcX},')
        ..writeln('        srcY: ${sprite.srcY},')
        ..writeln('        srcWidth: ${sprite.srcWidth},')
        ..writeln('        srcHeight: ${sprite.srcHeight},')
        ..writeln('        x: ${sprite.x},')
        ..writeln('        y: ${sprite.y},')
        ..writeln('        width: ${sprite.width},')
        ..writeln('        height: ${sprite.height},')
        ..writeln('        zIndex: ${sprite.zIndex},');
      if (sprite.flipX) {
        buffer.writeln('        flipX: true,');
      }
      if (sprite.flipY) {
        buffer.writeln('        flipY: true,');
      }
      buffer.writeln('      ),');
    }
    buffer.writeln('    ],');

    buffer.writeln('    spawnMarkers: <SpawnMarker>[');
    for (final marker in chunk.spawnMarkers) {
      buffer.writeln(
        '      SpawnMarker(enemyId: ${_enemyEnum(marker.enemyId)}, x: ${marker.x}, chancePercent: ${marker.chancePercent}, salt: ${marker.salt}, placement: ${_placementEnum(marker.placement)}),',
      );
    }
    buffer
      ..writeln('    ],')
      ..writeln('  ),');
  }
  buffer.writeln('];');
}

String _enemyEnum(EnemyId enemyId) => 'EnemyId.${enemyId.name}';

String _placementEnum(SpawnPlacementMode placement) =>
    'SpawnPlacementMode.${placement.name}';

String _patternsVariableName(String levelId, String difficulty) {
  return '${_toLowerCamelIdentifier(levelId)}${_toUpperCamelIdentifier(difficulty)}Patterns';
}

String _toLowerCamelIdentifier(String raw) {
  final parts = raw
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'patterns';
  }
  final first = parts.first;
  final buffer = StringBuffer('${first[0].toLowerCase()}${first.substring(1)}');
  for (final part in parts.skip(1)) {
    buffer.write(_toUpperCamelIdentifier(part));
  }
  return buffer.toString();
}

String _toUpperCamelIdentifier(String raw) {
  final parts = raw
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'Patterns';
  }
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write('${part[0].toUpperCase()}${part.substring(1)}');
  }
  return buffer.toString();
}

String _escape(String raw) {
  return raw.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
}

void _collectDuplicateIdentityIssues(
  List<_ChunkIdentity> identities,
  List<_ValidationIssue> issues, {
  required String fieldName,
  required String issueCode,
  required String Function(_ChunkIdentity identity) selector,
}) {
  final byScopedValue = <String, List<_ChunkIdentity>>{};
  for (final identity in identities) {
    final value = selector(identity);
    if (value.isEmpty || identity.levelId.isEmpty) continue;
    final scopedValue = '${identity.levelId}\u0000$value';
    byScopedValue
        .putIfAbsent(scopedValue, () => <_ChunkIdentity>[])
        .add(identity);
  }

  final sortedValues = byScopedValue.keys.toList()..sort();
  for (final scopedValue in sortedValues) {
    final entries = byScopedValue[scopedValue]!;
    if (entries.length < 2) continue;
    entries.sort((a, b) => a.path.compareTo(b.path));
    final value = selector(entries.first);
    final joinedPaths = entries.map((entry) => entry.path).join(', ');
    for (final entry in entries) {
      issues.add(
        _ValidationIssue(
          path: entry.path,
          code: issueCode,
          message:
              '$fieldName "$value" is duplicated within levelId "${entry.levelId}" across: $joinedPaths',
        ),
      );
    }
  }
}

void _validateLevelAssemblyAgainstChunks({
  required List<LevelDefinitionSource> levels,
  required List<_ChunkExportData> authoredChunks,
  required List<_ValidationIssue> issues,
}) {
  final groupCountsByLevel = <String, Map<String, int>>{};
  for (final chunk in authoredChunks) {
    final groupCounts = groupCountsByLevel.putIfAbsent(
      chunk.levelId,
      () => <String, int>{},
    );
    groupCounts[chunk.assemblyGroupId] =
        (groupCounts[chunk.assemblyGroupId] ?? 0) + 1;
  }

  for (final level in levels) {
    final assembly = level.assembly;
    if (assembly == null) {
      continue;
    }
    final declaredGroupIds = level.chunkThemeGroups.toSet();
    final availableGroups =
        groupCountsByLevel[level.levelId] ?? const <String, int>{};
    for (var i = 0; i < assembly.segments.length; i += 1) {
      final segment = assembly.segments[i];
      if (!declaredGroupIds.contains(segment.groupId)) {
        issues.add(
          _ValidationIssue(
            path: _levelDefsPath,
            code: 'unknown_assembly_group_id',
            message:
                'levels[${_levelIndexFor(levels, level.levelId)}].assembly.segments[$i] '
                'references groupId "${segment.groupId}" that is not declared '
                'in chunkThemeGroups for levelId "${level.levelId}".',
          ),
        );
        continue;
      }
      if (segment.requireDistinctChunks &&
          (availableGroups[segment.groupId] ?? 0) < segment.maxChunkCount) {
        issues.add(
          _ValidationIssue(
            path: _levelDefsPath,
            code: 'insufficient_distinct_group_chunks',
            message:
                'levels[${_levelIndexFor(levels, level.levelId)}].assembly.segments[$i] '
                'requires ${segment.maxChunkCount} distinct chunks, but '
                'group "${segment.groupId}" only has '
                '${availableGroups[segment.groupId] ?? 0}.',
          ),
        );
      }
    }
  }
}

void _validateChunkGroupsAgainstLevels({
  required List<LevelDefinitionSource> levels,
  required List<_ChunkExportData> authoredChunks,
  required List<_ValidationIssue> issues,
}) {
  final declaredGroupsByLevelId = <String, Set<String>>{
    for (final level in levels) level.levelId: level.chunkThemeGroups.toSet(),
  };
  for (final chunk in authoredChunks) {
    final declaredGroups = declaredGroupsByLevelId[chunk.levelId];
    if (declaredGroups == null) {
      continue;
    }
    if (declaredGroups.contains(chunk.assemblyGroupId)) {
      continue;
    }
    issues.add(
      _ValidationIssue(
        path: chunk.path,
        code: 'unknown_chunk_group_id',
        message:
            'assemblyGroupId "${chunk.assemblyGroupId}" is not declared in '
            'chunkThemeGroups for levelId "${chunk.levelId}".',
      ),
    );
  }
}

void _validateLevelVisualThemes({
  required List<LevelDefinitionSource> levels,
  required Set<String> authoredVisualThemeIds,
  required List<_ValidationIssue> issues,
}) {
  for (final level in levels) {
    if (!authoredVisualThemeIds.contains(level.visualThemeId)) {
      issues.add(
        _ValidationIssue(
          path: _levelDefsPath,
          code: 'missing_level_parallax_theme',
          message:
              'levels[${_levelIndexFor(levels, level.levelId)}].visualThemeId '
              'references unauthored theme "${level.visualThemeId}".',
        ),
      );
    }
  }
}

void _validateTerrainMaterialReferences(
  PolygonTerrainRepositoryGenerationResult terrain, {
  required Set<String> materialKeys,
  required List<_ValidationIssue> issues,
}) {
  final reported = <String>{};
  for (final chunk in terrain.chunks) {
    for (final polygon in chunk.compiled.renderGeometry.polygons) {
      final materialKey = polygon.materialKey;
      if (materialKey == null || materialKeys.contains(materialKey)) continue;
      final identity = polygon.identity;
      final reportKey = <String>[
        chunk.sourcePath,
        identity.placementKey ?? '',
        identity.shapeId,
        materialKey,
      ].join('|');
      if (!reported.add(reportKey)) continue;
      issues.add(
        _ValidationIssue(
          path: polygon.sourcePath,
          code: 'unknown_terrain_material_key',
          message:
              'Shape "${identity.shapeId}" references materialKey '
              '"$materialKey", which is absent from '
              '$terrainMaterialDefsPath.',
        ),
      );
    }
  }
}

int _levelIndexFor(List<LevelDefinitionSource> levels, String levelId) {
  for (var i = 0; i < levels.length; i += 1) {
    if (levels[i].levelId == levelId) {
      return i;
    }
  }
  return -1;
}

String _toRepoRelativePath(String path) {
  final normalizedPath = _normalizePath(path);
  final normalizedCwd = _normalizePath(Directory.current.path);
  final prefix = '$normalizedCwd/';
  if (normalizedPath.startsWith(prefix)) {
    return normalizedPath.substring(prefix.length);
  }
  return normalizedPath;
}

String _normalizePath(String path) {
  var normalized = path.replaceAll('\\', '/');
  normalized = normalized.replaceAll(RegExp(r'/+'), '/');
  if (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}

void _printUsage() {
  stdout.writeln('Generate runtime chunk data from authored chunk json files.');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run tool/generate_chunk_runtime_data.dart');
  stdout.writeln('  dart run tool/generate_chunk_runtime_data.dart --dry-run');
}

class _ChunkIdentity {
  const _ChunkIdentity({
    required this.path,
    required this.levelId,
    required this.chunkKey,
    required this.id,
  });

  final String path;
  final String levelId;
  final String chunkKey;
  final String id;
}

class _ChunkExportData {
  const _ChunkExportData({
    required this.path,
    required this.levelId,
    required this.difficulty,
    required this.pattern,
  });

  final String path;
  final String levelId;
  final String difficulty;
  final ChunkPattern pattern;

  String get chunkKey => pattern.chunkKey!;
  String get name => pattern.name;
  String get assemblyGroupId => pattern.assemblyGroupId;
  List<ChunkVisualSpriteRel> get visualSprites => pattern.visualSprites;
  List<SpawnMarker> get spawnMarkers => pattern.spawnMarkers;
}

class _ValidationIssue implements Comparable<_ValidationIssue> {
  const _ValidationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  @override
  int compareTo(_ValidationIssue other) {
    final pathCompare = path.compareTo(other.path);
    if (pathCompare != 0) return pathCompare;
    final codeCompare = code.compareTo(other.code);
    if (codeCompare != 0) return codeCompare;
    return message.compareTo(other.message);
  }
}
