import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import 'content_build_report.dart';
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

  final unknownArgs = args
      .where((arg) => arg != '--dry-run' && arg != '--machine-readable')
      .toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknownArgs.join(', ')}');
    _printUsage();
    exitCode = 64;
    return;
  }

  final dryRun = args.contains('--dry-run');
  final reporter = ContentBuildReporter(
    machineReadable: args.contains('--machine-readable'),
    dryRun: dryRun,
  );
  var cancelled = false;
  var replacementStarted = false;
  var outputsCommitted = false;
  StreamSubscription<String>? commands;
  if (reporter.machineReadable) {
    commands = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line == 'cancel' && !replacementStarted) cancelled = true;
        });
  }
  ContentBuildSnapshot? captured;
  Future<void> verifyBeforeReplacement() async {
    await Future<void>.delayed(Duration.zero);
    if (cancelled) {
      throw const ContentBuildInterruption(
        'build_cancelled',
        'Build cancelled before output replacement.',
      );
    }
    await captured!.verifyCurrent();
    if (cancelled) {
      throw const ContentBuildInterruption(
        'build_cancelled',
        'Build cancelled before output replacement.',
      );
    }
  }

  try {
    reporter.phase('capturing');
    captured = await ContentBuildSnapshot.capture();
    reporter.inputFingerprint = captured.fingerprint;
    reporter.phase('validating');
    final issues = <_ValidationIssue>[];
    final identities = <_ChunkIdentity>[];
    final authoredChunks = <_ChunkExportData>[];
    final files = captured.files.keys
        .where(
          (path) =>
              path.startsWith('$_chunksDirectoryPath/') &&
              path.endsWith('.json'),
        )
        .map(File.new)
        .toList();
    final levelResult = await loadLevelDefinitions(
      defsPath: _levelDefsPath,
      capturedInput: captured,
    );
    reporter.levels = [
      for (final level in levelResult.levels)
        {
          'levelId': level.levelId,
          'displayName': level.displayName,
          'includeInBuild': level.includeInBuild,
          'status': level.status,
        },
    ];
    final parallaxResult = await loadParallaxThemes(
      defsPath: _parallaxDefsPath,
      capturedInput: captured,
    );
    final terrainMaterialResult = await buildTerrainMaterialRegistry(
      capturedInput: captured,
    );
    final prefabContents = await _readRequiredText(
      _prefabDefsPath,
      issues,
      captured,
    );
    final tileContents = await _readRequiredText(
      _tileDefsPath,
      issues,
      captured,
    );
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
      final contents = await _readRequiredText(path, issues, captured);
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
      reporter.log('No chunk json files found under $_chunksDirectoryPath.');
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
              isRuntimeEligible: isRuntimeEligibleChunkStatus(
                chunk.source.status,
              ),
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

    if (!levelResult.levels.any(
      (level) => level.includeInBuild && level.status == activeLevelStatus,
    )) {
      issues.add(
        const _ValidationIssue(
          path: _levelDefsPath,
          code: 'no_included_active_level',
          message:
              'Build requires at least one included active playable Level.',
        ),
      );
    }

    issues.sort();

    if (issues.isNotEmpty) {
      for (final issue in issues) {
        stderr.writeln('[ERROR] ${issue.code} ${issue.path}: ${issue.message}');
      }
      stderr.writeln(
        'Validation failed with ${issues.length} blocking issue(s).',
      );
      reporter.finish(
        'invalid',
        issues: [
          for (final issue in issues)
            {
              'code': issue.code,
              'path': issue.path,
              'message': issue.message,
              'levelId': ?(issue.levelId ?? _levelIdFromChunkPath(issue.path)),
            },
        ],
      );
      exitCode = 1;
      return;
    }

    reporter.log('Validated ${files.length} chunk json file(s).');
    reporter.log('Validated ${levelResult.levels.length} level definition(s).');
    reporter.log(
      'Validated ${parallaxResult.themes.length} parallax theme definition(s).',
    );
    reporter.log(
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
    final includedLevelIds = levelResult.levels
        .where((level) => level.includeInBuild)
        .map((level) => level.levelId)
        .toSet();
    final runtimeChunks =
        authoredChunks
            .where(
              (chunk) =>
                  chunk.isRuntimeEligible &&
                  includedLevelIds.contains(chunk.levelId),
            )
            .toList()
          ..sort(_compareChunkExportData);
    final output = _renderDartOutput(runtimeChunks);
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
    reporter.outputs = artifactPlan.artifacts.map((a) => a.path).toList();
    reporter.phase('checking_outputs');
    final drift = await artifactPlan.inspectDrift();
    reporter.changes = [
      for (final item in drift)
        {
          'path': item.path,
          'kind': item.kind.name,
          'code': item.code,
          'message': item.message,
        },
    ];
    await verifyBeforeReplacement();
    if (dryRun) {
      for (final item in drift) {
        stderr.writeln('[ERROR] ${item.code} ${item.path}: ${item.message}');
      }
      reporter.finish(drift.isEmpty ? 'current' : 'drift');
      if (drift.isNotEmpty) {
        stderr.writeln(
          'Generated output drift found in ${drift.length} file(s).',
        );
        exitCode = 1;
      } else {
        reporter.log('Dry-run completed with no blocking issues.');
      }
      return;
    }
    final blocked = drift
        .where(
          (d) =>
              d.kind == GeneratedArtifactDriftKind.unexpected ||
              d.kind == GeneratedArtifactDriftKind.unreadable,
        )
        .toList();
    if (blocked.isNotEmpty) {
      reporter.finish(
        'failed',
        issues: [
          for (final item in blocked)
            {'code': item.code, 'path': item.path, 'message': item.message},
        ],
      );
      exitCode = 1;
      return;
    }
    reporter.phase('staging');
    await artifactPlan.writeAll(
      beforeReplacement: verifyBeforeReplacement,
      onReplacementStarted: () {
        replacementStarted = true;
        reporter.phase('committing');
      },
    );
    outputsCommitted = true;
    reporter.phase('verifying');
    await captured.verifyCurrent();
    final remainingDrift = await artifactPlan.inspectDrift();
    if (remainingDrift.isNotEmpty) {
      reporter.finish(
        'failed',
        outputsCommitted: true,
        issues: [
          for (final item in remainingDrift)
            {'code': item.code, 'path': item.path, 'message': item.message},
        ],
      );
      exitCode = 1;
      return;
    }
    reporter.finish('built', outputsCommitted: true);
    reporter.log('Generated $_outputPath (${authoredChunks.length} chunk(s)).');
    reporter.log(
      'Generated $_levelIdOutputPath (${levelResult.levels.length} level(s)).',
    );
    reporter.log(
      'Generated $_levelRegistryOutputPath '
      '(${levelResult.levels.length} level(s)).',
    );
    reporter.log(
      'Generated $_levelUiMetadataOutputPath '
      '(${levelResult.levels.length} level(s)).',
    );
    reporter.log(
      'Generated $_parallaxOutputPath '
      '(${parallaxResult.themes.length} theme(s)).',
    );
    reporter.log(
      'Generated ${terrainMaterialResult.output!.path} '
      '(${terrainMaterialResult.catalog!.materials.length} material(s)).',
    );
    reporter.log(
      'Generated ${stagedTerrainOutput.path} '
      '(${terrainResult.chunks.length} chunk(s), staged only).',
    );
  } on Object catch (error) {
    final transaction = error is GeneratedArtifactWriteException ? error : null;
    final cause = transaction?.cause ?? error;
    final interruption = cause is ContentBuildInterruption ? cause : null;
    reporter.finish(
      interruption?.code == 'build_cancelled'
          ? 'cancelled'
          : interruption?.code == 'build_source_drift'
          ? 'stale'
          : 'failed',
      issues: [
        {
          'code': interruption?.code ?? 'build_failed',
          'message': interruption?.message ?? error.toString(),
        },
      ],
      outputsCommitted:
          outputsCommitted || (transaction?.outputsCommitted ?? false),
      rollbackComplete: transaction?.rollbackComplete ?? false,
      transactionFailures: transaction?.rollbackFailures ?? const [],
    );
    stderr.writeln('Chunk generation failed: $error');
    exitCode = 1;
  } finally {
    await commands?.cancel();
  }
}

PolygonTerrainSchedulerLevelSource _terrainSchedulerLevel(
  LevelDefinitionSource level,
) => PolygonTerrainSchedulerLevelSource(
  levelId: level.levelId,
  groundTopY: level.groundTopY,
  earlyPatternChunks: level.earlyPatternChunks,
  easyPatternChunks: level.easyPatternChunks,
  normalPatternChunks: level.normalPatternChunks,
  firstChunkKey: level.firstChunkKey,
  includeInBuild: level.includeInBuild,
  assembly: level.assembly == null
      ? null
      : PolygonTerrainSchedulerAssemblySource(
          loopSegments: level.assembly!.loopSegments,
          segments: <PolygonTerrainSchedulerSegmentSource>[
            for (final segment in level.assembly!.segments)
              PolygonTerrainSchedulerSegmentSource(
                segmentId: segment.segmentId,
                groupId: segment.groupId,
                difficulty: segment.difficulty,
                minChunkCount: segment.minChunkCount,
                maxChunkCount: segment.maxChunkCount,
                requireDistinctChunks: segment.requireDistinctChunks,
              ),
          ],
        ),
);

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
  ContentBuildSnapshot captured,
) async {
  if (!captured.contains(relativePath)) {
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
    return captured.readString(relativePath);
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
  final difficultyCompare = _difficultyIndex(a.difficulty)
      .compareTo(_difficultyIndex(b.difficulty));
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
    if (!chunk.isRuntimeEligible) continue;
    final groupCounts = groupCountsByLevel.putIfAbsent(
      chunk.levelId,
      () => <String, int>{},
    );
    groupCounts[chunk.assemblyGroupId] =
        (groupCounts[chunk.assemblyGroupId] ?? 0) + 1;
  }

  for (final level in levels) {
    if (level.includeInBuild &&
        !groupCountsByLevel.containsKey(level.levelId)) {
      issues.add(
        _ValidationIssue(
          path: _levelDefsPath,
          code: 'included_level_has_no_active_chunks',
          levelId: level.levelId,
          message:
              'Included Level ${level.levelId} requires at least one active chunk.',
        ),
      );
    }
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
            levelId: level.levelId,
            message:
                'levels[${_levelIndexFor(levels, level.levelId)}].assembly.segments[$i] '
                'references groupId "${segment.groupId}" that is not declared '
                'in chunkThemeGroups for levelId "${level.levelId}".',
          ),
        );
        continue;
      }
      if (level.includeInBuild &&
          segment.requireDistinctChunks &&
          (availableGroups[segment.groupId] ?? 0) < segment.maxChunkCount) {
        issues.add(
          _ValidationIssue(
            path: _levelDefsPath,
            code: 'insufficient_distinct_group_chunks',
            levelId: level.levelId,
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
    for (final water in chunk.compiled.chunk.waterRegions) {
      if (!materialKeys.contains(water.materialKey)) {
        issues.add(
          _ValidationIssue(
            path: chunk.sourcePath,
            code: 'unknown_water_material_key',
            message:
                'Water "${water.id}" references unavailable material "${water.materialKey}".',
          ),
        );
      }
    }
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
  stdout.writeln(
    '  Add --machine-readable for versioned JSON-line progress/results.',
  );
  stdout.writeln(
    '  In machine mode, send "cancel" on stdin before output replacement.',
  );
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
    required this.isRuntimeEligible,
    required this.pattern,
  });

  final String path;
  final String levelId;
  final String difficulty;
  final bool isRuntimeEligible;
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
    this.levelId,
  });

  final String path;
  final String code;
  final String message;
  final String? levelId;

  @override
  int compareTo(_ValidationIssue other) {
    final pathCompare = path.compareTo(other.path);
    if (pathCompare != 0) return pathCompare;
    final codeCompare = code.compareTo(other.code);
    if (codeCompare != 0) return codeCompare;
    return message.compareTo(other.message);
  }
}
