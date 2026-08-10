import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_polygon.dart';

import 'generated_artifact_plan.dart';
import 'level_definition_generation.dart';
import 'parallax_theme_generation.dart';
import 'polygon_terrain_legacy_projection.dart';
import 'polygon_terrain_render.dart';
import 'polygon_terrain_repository_generation.dart';

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
const int _gridSnap = 16;
const double _defaultPrefabScale = 1.0;
const double _minPrefabScale = 0.3;
const double _maxPrefabScale = 3.0;
const double _prefabScaleStep = 0.1;
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
    final prefabRegistry = await _loadPrefabRegistry(issues);
    final prefabContents = await _readRequiredText(_prefabDefsPath, issues);
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
        levels: levelResult.levels,
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
        final parsed = _parseCurrentChunkExport(
          chunk,
          chunkContentsByPath[chunk.sourcePath]!,
          issues,
          prefabRegistry: prefabRegistry,
        );
        identities.add(parsed.identity);
        authoredChunks.add(parsed.exportData);
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
      'Generated ${stagedTerrainOutput.path} '
      '(${terrainResult.chunks.length} chunk(s), staged only).',
    );
  } on Object catch (error) {
    stderr.writeln('Chunk generation failed: $error');
    exitCode = 1;
  }
}

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

_ChunkParseResult _parseCurrentChunkExport(
  PolygonTerrainRepositoryChunk terrain,
  String raw,
  List<_ValidationIssue> issues, {
  required _PrefabRegistry prefabRegistry,
}) {
  final path = terrain.sourcePath;
  final decoded = jsonDecode(raw)! as Map<String, Object?>;
  final source = terrain.source;
  _validateLevelOwnershipPath(
    path: path,
    levelId: source.levelId,
    issues: issues,
  );

  final chunk = _ChunkJson(
    path: path,
    chunkKey: source.chunkKey,
    id: source.id,
    levelId: source.levelId,
    difficulty: source.difficulty,
    assemblyGroupId: source.assemblyGroupId,
    prefabs: _readListOfMaps(decoded['prefabs']),
    markers: _readListOfMaps(decoded['markers']),
  );

  final exportData = _buildChunkExportData(
    chunk,
    issues,
    prefabRegistry: prefabRegistry,
    legacyProjection: terrain.legacyProjection,
  );
  return _ChunkParseResult(
    identity: _ChunkIdentity(
      path: path,
      levelId: source.levelId,
      chunkKey: source.chunkKey,
      id: source.id,
    ),
    exportData: exportData,
  );
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

List<Map<String, Object?>> _readListOfMaps(Object? raw) {
  if (raw is! List<Object?>) {
    return const <Map<String, Object?>>[];
  }
  final out = <Map<String, Object?>>[];
  for (final item in raw) {
    if (item is Map<String, Object?>) {
      out.add(item);
    }
  }
  return out;
}

Future<_PrefabRegistry> _loadPrefabRegistry(
  List<_ValidationIssue> issues,
) async {
  final prefabDefs = await _readJsonObjectFile(_prefabDefsPath, issues);
  final tileDefs = await _readJsonObjectFile(_tileDefsPath, issues);

  final slicesById = <String, _SliceDef>{};
  for (final json in _readListOfMaps(prefabDefs['slices'])) {
    final id = _normalizedString(json['id']);
    if (id.isEmpty) continue;
    slicesById[id] = _SliceDef(
      id: id,
      assetPath: _normalizedString(json['sourceImagePath']),
      x: _intOrZero(json['x']),
      y: _intOrZero(json['y']),
      width: _intOrZero(json['width']),
      height: _intOrZero(json['height']),
    );
  }
  for (final json in _readListOfMaps(tileDefs['tileSlices'])) {
    final id = _normalizedString(json['id']);
    if (id.isEmpty) continue;
    slicesById[id] = _SliceDef(
      id: id,
      assetPath: _normalizedString(json['sourceImagePath']),
      x: _intOrZero(json['x']),
      y: _intOrZero(json['y']),
      width: _intOrZero(json['width']),
      height: _intOrZero(json['height']),
    );
  }

  final modulesById = <String, _ModuleDef>{};
  for (final json in _readListOfMaps(tileDefs['platformModules'])) {
    final id = _normalizedString(json['id']);
    if (id.isEmpty) continue;
    final cells = <_ModuleCell>[];
    for (final cell in _readListOfMaps(json['cells'])) {
      final sliceId = _normalizedString(cell['sliceId']);
      if (sliceId.isEmpty) continue;
      cells.add(
        _ModuleCell(
          sliceId: sliceId,
          gridX: _intOrZero(cell['gridX']),
          gridY: _intOrZero(cell['gridY']),
        ),
      );
    }
    modulesById[id] = _ModuleDef(id: id, cells: cells);
  }

  final prefabsByKey = <String, _PrefabDef>{};
  for (final json in _readListOfMaps(prefabDefs['prefabs'])) {
    final key = _normalizedString(json['prefabKey']);
    if (key.isEmpty) continue;
    final visual = json['visualSource'];
    String visualType = '';
    String visualRefId = '';
    if (visual is Map<String, Object?>) {
      visualType = _normalizedString(visual['type']);
      visualRefId = _normalizedString(
        visualType == 'platform_module'
            ? visual['moduleId']
            : visual['sliceId'],
      );
    }

    prefabsByKey[key] = _PrefabDef(
      prefabKey: key,
      kind: _normalizedString(json['kind']),
      anchorX: _intOrZero(json['anchorXPx']).toDouble(),
      anchorY: _intOrZero(json['anchorYPx']).toDouble(),
      visualType: visualType,
      visualRefId: visualRefId,
    );
  }

  return _PrefabRegistry(
    prefabsByKey: prefabsByKey,
    slicesById: slicesById,
    modulesById: modulesById,
  );
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

Future<Map<String, Object?>> _readJsonObjectFile(
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
    return <String, Object?>{};
  }
  try {
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    issues.add(
      _ValidationIssue(
        path: relativePath,
        code: 'invalid_root_type',
        message: 'Top-level JSON value must be an object.',
      ),
    );
  } on Object catch (error) {
    issues.add(
      _ValidationIssue(
        path: relativePath,
        code: 'read_failed',
        message: 'Unable to read/parse file: $error',
      ),
    );
  }
  return <String, Object?>{};
}

_ChunkExportData _buildChunkExportData(
  _ChunkJson chunk,
  List<_ValidationIssue> issues, {
  required _PrefabRegistry prefabRegistry,
  required PolygonTerrainLegacyProjection legacyProjection,
}) {
  final solids = <_SolidExport>[
    for (final rectangle in legacyProjection.rectangles)
      _SolidExport(
        x: rectangle.x,
        aboveGroundTop: legacyProjection.groundTopY - rectangle.topY,
        width: rectangle.width,
        height: rectangle.height,
        sides: rectangle.collisionMode == TerrainCollisionMode.oneWay
            ? _SolidExport.sideTop
            : _SolidExport.sideAll,
        oneWayTop: rectangle.collisionMode == TerrainCollisionMode.oneWay,
      ),
  ];
  final visualSprites = <_VisualSpriteExport>[];
  final groundGaps = <_GroundGapExport>[
    for (final gap in legacyProjection.groundGaps)
      _GroundGapExport(gapId: gap.gapId, x: gap.x, width: gap.width),
  ];
  final markers = <_MarkerExport>[];

  for (final marker in chunk.markers) {
    final markerId = _normalizedString(marker['markerId']);
    final enemyId = _enemyEnumFor(markerId);
    if (enemyId == null) {
      issues.add(
        _ValidationIssue(
          path: chunk.path,
          code: 'unknown_enemy_marker_id',
          message: 'Unknown markerId "$markerId".',
        ),
      );
      continue;
    }
    markers.add(
      _MarkerExport(
        enemyEnum: enemyId,
        x: _intOrZero(marker['x']),
        chancePercent: _intOrDefault(marker['chancePercent'], 100),
        salt: _intOrDefault(marker['salt'], 0),
        placementEnum: _placementEnumFor(
          _normalizedString(marker['placement']),
        ),
      ),
    );
  }

  for (final placed in chunk.prefabs) {
    final prefabKey = _normalizedString(placed['prefabKey']);
    final prefab = prefabRegistry.prefabsByKey[prefabKey];
    if (prefab == null) {
      issues.add(
        _ValidationIssue(
          path: chunk.path,
          code: 'missing_prefab_key',
          message: 'Placed prefab references unknown prefabKey "$prefabKey".',
        ),
      );
      continue;
    }

    final placementX = _intOrZero(placed['x']).toDouble();
    final placementY = _intOrZero(placed['y']).toDouble();
    final scale = _doubleOrDefault(placed['scale'], _defaultPrefabScale);
    final flipX = _boolOrDefault(placed['flipX'], false);
    final flipY = _boolOrDefault(placed['flipY'], false);
    final validScaleRange =
        scale >= _minPrefabScale && scale <= _maxPrefabScale;
    final validScaleStep = _isStepAligned(scale, _prefabScaleStep);
    if (!validScaleRange) {
      issues.add(
        _ValidationIssue(
          path: chunk.path,
          code: 'prefab_scale_out_of_range',
          message:
              'Placed prefab "$prefabKey" scale $scale must be between '
              '$_minPrefabScale and $_maxPrefabScale.',
        ),
      );
      continue;
    }
    if (!validScaleStep) {
      issues.add(
        _ValidationIssue(
          path: chunk.path,
          code: 'prefab_scale_step_violation',
          message:
              'Placed prefab "$prefabKey" scale $scale must use step '
              '$_prefabScaleStep.',
        ),
      );
      continue;
    }

    final spriteEntries = _buildVisualSprites(
      prefab: prefab,
      placementX: placementX,
      placementY: placementY,
      scale: scale,
      flipX: flipX,
      flipY: flipY,
      registry: prefabRegistry,
      chunkPath: chunk.path,
      issues: issues,
      zIndex: _intOrDefault(placed['zIndex'], 0),
    );
    visualSprites.addAll(spriteEntries);
  }

  return _ChunkExportData(
    path: chunk.path,
    levelId: chunk.levelId,
    difficulty: chunk.difficulty,
    chunkKey: chunk.chunkKey,
    name: chunk.id,
    assemblyGroupId: chunk.assemblyGroupId,
    solids: solids,
    groundGaps: groundGaps,
    visualSprites: visualSprites,
    spawnMarkers: markers,
  );
}

List<_VisualSpriteExport> _buildVisualSprites({
  required _PrefabDef prefab,
  required double placementX,
  required double placementY,
  required double scale,
  required bool flipX,
  required bool flipY,
  required _PrefabRegistry registry,
  required String chunkPath,
  required List<_ValidationIssue> issues,
  required int zIndex,
}) {
  if (prefab.visualType == 'atlas_slice') {
    final slice = registry.slicesById[prefab.visualRefId];
    if (slice == null) {
      issues.add(
        _ValidationIssue(
          path: chunkPath,
          code: 'missing_slice',
          message: 'Missing atlas slice "${prefab.visualRefId}".',
        ),
      );
      return const <_VisualSpriteExport>[];
    }
    return <_VisualSpriteExport>[
      _VisualSpriteExport(
        assetPath: _runtimeAssetPath(slice.assetPath),
        srcX: slice.x,
        srcY: slice.y,
        srcWidth: slice.width,
        srcHeight: slice.height,
        x:
            placementX +
            _transformLocalAxisStart(
              start: -(prefab.anchorX * scale),
              extent: slice.width.toDouble() * scale,
              flip: flipX,
            ),
        y:
            placementY +
            _transformLocalAxisStart(
              start: -(prefab.anchorY * scale),
              extent: slice.height.toDouble() * scale,
              flip: flipY,
            ),
        width: slice.width.toDouble() * scale,
        height: slice.height.toDouble() * scale,
        zIndex: zIndex,
        flipX: flipX,
        flipY: flipY,
      ),
    ];
  }

  if (prefab.visualType == 'platform_module') {
    final module = registry.modulesById[prefab.visualRefId];
    if (module == null) {
      issues.add(
        _ValidationIssue(
          path: chunkPath,
          code: 'missing_module',
          message: 'Missing platform module "${prefab.visualRefId}".',
        ),
      );
      return const <_VisualSpriteExport>[];
    }
    final sprites = <_VisualSpriteExport>[];
    for (final cell in module.cells) {
      final slice = registry.slicesById[cell.sliceId];
      if (slice == null) {
        issues.add(
          _ValidationIssue(
            path: chunkPath,
            code: 'missing_tile_slice',
            message:
                'Missing tile slice "${cell.sliceId}" for module "${module.id}".',
          ),
        );
        continue;
      }
      sprites.add(
        _VisualSpriteExport(
          assetPath: _runtimeAssetPath(slice.assetPath),
          srcX: slice.x,
          srcY: slice.y,
          srcWidth: slice.width,
          srcHeight: slice.height,
          x:
              placementX +
              _transformLocalAxisStart(
                start:
                    -(prefab.anchorX * scale) +
                    (cell.gridX * _gridSnap * scale),
                extent: slice.width.toDouble() * scale,
                flip: flipX,
              ),
          y:
              placementY +
              _transformLocalAxisStart(
                start:
                    -(prefab.anchorY * scale) +
                    (cell.gridY * _gridSnap * scale),
                extent: slice.height.toDouble() * scale,
                flip: flipY,
              ),
          width: slice.width.toDouble() * scale,
          height: slice.height.toDouble() * scale,
          zIndex: zIndex,
          flipX: flipX,
          flipY: flipY,
        ),
      );
    }
    return sprites;
  }

  return const <_VisualSpriteExport>[];
}

String _runtimeAssetPath(String authoredPath) {
  const prefix = 'assets/images/';
  if (authoredPath.startsWith(prefix)) {
    return authoredPath.substring(prefix.length);
  }
  return authoredPath;
}

double _transformLocalAxisStart({
  required double start,
  required double extent,
  required bool flip,
}) {
  if (!flip) {
    return start;
  }
  return -(start + extent);
}

String? _enemyEnumFor(String markerId) {
  switch (markerId) {
    case 'derf':
      return 'EnemyId.derf';
    case 'grojib':
      return 'EnemyId.grojib';
    case 'hashash':
      return 'EnemyId.hashash';
    case 'unocoDemon':
      return 'EnemyId.unocoDemon';
    default:
      return null;
  }
}

String _placementEnumFor(String raw) {
  switch (raw) {
    case 'highestSurfaceAtX':
      return 'SpawnPlacementMode.highestSurfaceAtX';
    case 'obstacleTop':
      return 'SpawnPlacementMode.obstacleTop';
    case 'ground':
    default:
      return 'SpawnPlacementMode.ground';
  }
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

int _intOrDefault(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _doubleOrDefault(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return fallback;
}

bool _boolOrDefault(Object? value, bool fallback) {
  if (value is bool) return value;
  return fallback;
}

bool _isStepAligned(double value, double step) {
  if (!value.isFinite || step <= 0) {
    return false;
  }
  final aligned = (value / step).roundToDouble() * step;
  return (value - aligned).abs() < 1e-9;
}

String _normalizedString(Object? raw, {String fallback = ''}) {
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
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

    buffer.writeln('    solids: <SolidRel>[');
    for (final solid in chunk.solids) {
      buffer.writeln(
        '      SolidRel(x: ${solid.x.toDouble()}, aboveGroundTop: ${solid.aboveGroundTop.toDouble()}, width: ${solid.width.toDouble()}, height: ${solid.height.toDouble()}, sides: ${_solidSidesExpression(solid.sides)}, oneWayTop: ${solid.oneWayTop}),',
      );
    }
    buffer.writeln('    ],');

    buffer.writeln('    groundGaps: <GapRel>[');
    for (final gap in chunk.groundGaps) {
      if (gap.gapId.isEmpty) {
        buffer.writeln(
          '      GapRel(x: ${gap.x.toDouble()}, width: ${gap.width.toDouble()}),',
        );
      } else {
        buffer.writeln(
          "      GapRel(gapId: '${_escape(gap.gapId)}', x: ${gap.x.toDouble()}, width: ${gap.width.toDouble()}),",
        );
      }
    }
    buffer.writeln('    ],');

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
        '      SpawnMarker(enemyId: ${marker.enemyEnum}, x: ${marker.x.toDouble()}, chancePercent: ${marker.chancePercent}, salt: ${marker.salt}, placement: ${marker.placementEnum}),',
      );
    }
    buffer
      ..writeln('    ],')
      ..writeln('  ),');
  }
  buffer.writeln('];');
}

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

String _solidSidesExpression(int sides) {
  if (sides == _SolidExport.sideNone) {
    return 'SolidRel.sideNone';
  }
  if (sides == _SolidExport.sideAll) {
    return 'SolidRel.sideAll';
  }

  final parts = <String>[];
  if ((sides & _SolidExport.sideTop) != 0) {
    parts.add('SolidRel.sideTop');
  }
  if ((sides & _SolidExport.sideBottom) != 0) {
    parts.add('SolidRel.sideBottom');
  }
  if ((sides & _SolidExport.sideLeft) != 0) {
    parts.add('SolidRel.sideLeft');
  }
  if ((sides & _SolidExport.sideRight) != 0) {
    parts.add('SolidRel.sideRight');
  }
  if (parts.isEmpty) {
    return '$sides';
  }
  return parts.join(' | ');
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

class _ChunkParseResult {
  const _ChunkParseResult({required this.identity, required this.exportData});

  final _ChunkIdentity identity;
  final _ChunkExportData exportData;
}

class _ChunkJson {
  const _ChunkJson({
    required this.path,
    required this.chunkKey,
    required this.id,
    required this.levelId,
    required this.difficulty,
    required this.assemblyGroupId,
    required this.prefabs,
    required this.markers,
  });

  final String path;
  final String chunkKey;
  final String id;
  final String levelId;
  final String difficulty;
  final String assemblyGroupId;
  final List<Map<String, Object?>> prefabs;
  final List<Map<String, Object?>> markers;
}

class _PrefabRegistry {
  const _PrefabRegistry({
    required this.prefabsByKey,
    required this.slicesById,
    required this.modulesById,
  });

  final Map<String, _PrefabDef> prefabsByKey;
  final Map<String, _SliceDef> slicesById;
  final Map<String, _ModuleDef> modulesById;
}

class _PrefabDef {
  const _PrefabDef({
    required this.prefabKey,
    required this.kind,
    required this.anchorX,
    required this.anchorY,
    required this.visualType,
    required this.visualRefId,
  });

  final String prefabKey;
  final String kind;
  final double anchorX;
  final double anchorY;
  final String visualType;
  final String visualRefId;
}

class _SliceDef {
  const _SliceDef({
    required this.id,
    required this.assetPath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final String assetPath;
  final int x;
  final int y;
  final int width;
  final int height;
}

class _ModuleDef {
  const _ModuleDef({required this.id, required this.cells});

  final String id;
  final List<_ModuleCell> cells;
}

class _ModuleCell {
  const _ModuleCell({
    required this.sliceId,
    required this.gridX,
    required this.gridY,
  });

  final String sliceId;
  final int gridX;
  final int gridY;
}

class _ChunkExportData {
  const _ChunkExportData({
    required this.path,
    required this.levelId,
    required this.difficulty,
    required this.chunkKey,
    required this.name,
    required this.assemblyGroupId,
    required this.solids,
    required this.groundGaps,
    required this.visualSprites,
    required this.spawnMarkers,
  });

  final String path;
  final String levelId;
  final String difficulty;
  final String chunkKey;
  final String name;
  final String assemblyGroupId;
  final List<_SolidExport> solids;
  final List<_GroundGapExport> groundGaps;
  final List<_VisualSpriteExport> visualSprites;
  final List<_MarkerExport> spawnMarkers;
}

class _SolidExport {
  const _SolidExport({
    required this.x,
    required this.aboveGroundTop,
    required this.width,
    required this.height,
    required this.sides,
    required this.oneWayTop,
  });

  final int x;
  final int aboveGroundTop;
  final int width;
  final int height;
  final int sides;
  final bool oneWayTop;

  static const int sideNone = 0;
  static const int sideTop = 1 << 0;
  static const int sideBottom = 1 << 1;
  static const int sideLeft = 1 << 2;
  static const int sideRight = 1 << 3;
  static const int sideAll = sideTop | sideBottom | sideLeft | sideRight;
}

class _GroundGapExport {
  const _GroundGapExport({
    required this.gapId,
    required this.x,
    required this.width,
  });

  final String gapId;
  final int x;
  final int width;
}

class _VisualSpriteExport {
  const _VisualSpriteExport({
    required this.assetPath,
    required this.srcX,
    required this.srcY,
    required this.srcWidth,
    required this.srcHeight,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    required this.flipX,
    required this.flipY,
  });

  final String assetPath;
  final int srcX;
  final int srcY;
  final int srcWidth;
  final int srcHeight;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final bool flipX;
  final bool flipY;
}

class _MarkerExport {
  const _MarkerExport({
    required this.enemyEnum,
    required this.x,
    required this.chancePercent,
    required this.salt,
    required this.placementEnum,
  });

  final String enemyEnum;
  final int x;
  final int chancePercent;
  final int salt;
  final String placementEnum;
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
