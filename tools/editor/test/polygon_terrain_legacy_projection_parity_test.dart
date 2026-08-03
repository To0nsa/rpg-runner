import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/track/authored_chunk_patterns.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_editor/src/migration/polygon_authoring_migration_check.dart';

import '../../../tool/polygon_terrain_compilation.dart';
import '../../../tool/polygon_terrain_legacy_projection.dart';
import '../../../tool/polygon_terrain_source.dart';

void main() {
  test(
    'repository collision-cleared projection matches every legacy chunk',
    () {
      final root = _repoRootPath();
      final check = PolygonAuthoringMigrationCheck.fromRepository(root);
      expect(check.hasBlockers, isFalse);
      final prefabTarget = check.targetFiles.singleWhere(
        (target) => target.sourceKind == 'prefabs',
      );
      final prefabs = decodePolygonTerrainPrefabs(
        prefabTarget.canonicalContents,
        sourcePath: prefabTarget.sourcePath,
      );
      final groundTopByLevel = _groundTopByLevel(root);
      final patterns = <ChunkPattern>[
        ...fieldEarlyPatterns,
        ...fieldEasyPatterns,
        ...fieldNormalPatterns,
        ...fieldHardPatterns,
        ...forestEarlyPatterns,
        ...forestEasyPatterns,
        ...forestNormalPatterns,
        ...forestHardPatterns,
      ];
      final patternByKey = <String, ChunkPattern>{
        for (final pattern in patterns) pattern.chunkKey!: pattern,
      };
      final chunkTargets = check.targetFiles
          .where((target) => target.sourceKind == 'chunk')
          .toList(growable: false);
      final compilationFailures = <String>[];
      final blockedChunkKeys = <String>{};
      var projectedChunkCount = 0;

      expect(chunkTargets, hasLength(8));
      expect(patternByKey, hasLength(8));
      for (final target in chunkTargets) {
        final chunk = decodePolygonTerrainChunk(
          target.canonicalContents,
          sourcePath: target.sourcePath,
        );
        final compilation = compilePolygonTerrainChunk(
          chunk: chunk,
          prefabSources: prefabs,
          sourcePath: target.sourcePath,
        );
        if (compilation.issues.isNotEmpty) {
          blockedChunkKeys.add(chunk.chunkKey);
          compilationFailures.addAll(
            compilation.issues.map(
              (issue) => '${chunk.chunkKey}: ${issue.code} ${issue.sourcePath}',
            ),
          );
          continue;
        }
        projectedChunkCount += 1;
        final projection = projectPolygonTerrainToLegacy(
          compiled: compilation.compiled!,
          legacyGroundTopY: groundTopByLevel[chunk.levelId]!,
        );
        expect(projection.issues, isEmpty, reason: chunk.chunkKey);
        final actual = projection.projection!;
        final expected = patternByKey[chunk.chunkKey]!;

        expect(_gapRecords(actual), _gapRecordsForPattern(expected));
        expect(
          _solidPixels(actual.rectangles),
          _solidPixelsForPattern(expected, actual.groundTopY),
          reason: '${chunk.chunkKey} solid occupied pixels',
        );
        expect(
          _oneWayTopPixels(actual.rectangles),
          _oneWayTopPixelsForPattern(expected, actual.groundTopY),
          reason: '${chunk.chunkKey} one-way top pixels',
        );
      }
      expect(projectedChunkCount, 8);
      expect(compilationFailures, isEmpty);
      expect(blockedChunkKeys, isEmpty);
    },
  );
}

Map<String, int> _groundTopByLevel(String root) {
  final source = File(
    p.join(root, 'assets', 'authoring', 'level', 'level_defs.json'),
  ).readAsStringSync();
  final decoded = jsonDecode(source) as Map<String, Object?>;
  final result = <String, int>{};
  for (final raw in decoded['levels']! as List<Object?>) {
    final level = raw! as Map<String, Object?>;
    result[level['levelId']! as String] = level['groundTopY']! as int;
  }
  return result;
}

List<(String, int, int)> _gapRecords(
  PolygonTerrainLegacyProjection projection,
) => <(String, int, int)>[
  for (final gap in projection.groundGaps) (gap.gapId, gap.x, gap.width),
];

List<(String, int, int)> _gapRecordsForPattern(ChunkPattern pattern) =>
    <(String, int, int)>[
      for (final gap in pattern.groundGaps)
        (gap.gapId!, _integer(gap.x), _integer(gap.width)),
    ];

Set<(int, int)> _solidPixels(List<PolygonTerrainLegacyRectangle> rectangles) {
  final pixels = <(int, int)>{};
  for (final rectangle in rectangles) {
    if (rectangle.collisionMode != TerrainCollisionMode.solid) continue;
    for (var x = rectangle.x; x < rectangle.right; x += 1) {
      for (var y = rectangle.topY; y < rectangle.bottom; y += 1) {
        pixels.add((x, y));
      }
    }
  }
  return pixels;
}

Set<(int, int)> _solidPixelsForPattern(ChunkPattern pattern, int groundTopY) {
  final pixels = <(int, int)>{};
  for (final solid in pattern.solids) {
    if (solid.oneWayTop) continue;
    expect(solid.sides, SolidRel.sideAll);
    final left = _integer(solid.x);
    final top = groundTopY - _integer(solid.aboveGroundTop);
    final right = left + _integer(solid.width);
    final bottom = top + _integer(solid.height);
    for (var x = left; x < right; x += 1) {
      for (var y = top; y < bottom; y += 1) {
        pixels.add((x, y));
      }
    }
  }
  return pixels;
}

Set<(int, int)> _oneWayTopPixels(
  List<PolygonTerrainLegacyRectangle> rectangles,
) {
  final pixels = <(int, int)>{};
  for (final rectangle in rectangles) {
    if (rectangle.collisionMode != TerrainCollisionMode.oneWay) continue;
    for (var x = rectangle.x; x < rectangle.right; x += 1) {
      pixels.add((x, rectangle.topY));
    }
  }
  return pixels;
}

Set<(int, int)> _oneWayTopPixelsForPattern(
  ChunkPattern pattern,
  int groundTopY,
) {
  final pixels = <(int, int)>{};
  for (final solid in pattern.solids) {
    if (!solid.oneWayTop) continue;
    expect(solid.sides, SolidRel.sideTop);
    final left = _integer(solid.x);
    final top = groundTopY - _integer(solid.aboveGroundTop);
    final right = left + _integer(solid.width);
    for (var x = left; x < right; x += 1) {
      pixels.add((x, top));
    }
  }
  return pixels;
}

int _integer(double value) {
  expect(value, value.roundToDouble());
  return value.toInt();
}

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
