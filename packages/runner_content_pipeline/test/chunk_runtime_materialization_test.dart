import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:test/test.dart';

void main() {
  test('single source boundary returns typed staged terrain and pattern', () {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: _prefabs,
      tileSourcePath: 'assets/authoring/level/tile_defs.json',
      tileContents: _tiles,
      chunkSourcePath: 'assets/authoring/level/chunks/forest/preview.json',
      chunkContents: _chunk,
    );

    expect(result.issues, isEmpty);
    final runtime = result.chunk!;
    expect(runtime.stagedTerrain.chunkKey, 'preview');
    expect(runtime.stagedTerrain.polygons, hasLength(1));
    expect(runtime.stagedTerrain.edges, hasLength(4));
    expect(runtime.stagedTerrain.triangles, hasLength(2));
    expect(
      runtime.stagedTerrain.sourceSignature,
      runtime.compiled.geometry.sourceSignature(),
    );
    expect(
      runtime.stagedTerrain.triangleSignature,
      runtime.compiled.triangleSignature(),
    );
    expect(runtime.pattern.name, 'preview');
    expect(runtime.pattern.chunkKey, 'preview');
    expect(runtime.pattern.assemblyGroupId, 'default');
    expect(runtime.pattern.visualSprites, hasLength(1));
    final sprite = runtime.pattern.visualSprites.single;
    expect(sprite.assetPath, 'level/props.png');
    expect(sprite.x, 95);
    expect(sprite.y, 185);
    expect(sprite.width, 16);
    expect(sprite.height, 20);
    expect(runtime.pattern.spawnMarkers, hasLength(1));
    final marker = runtime.pattern.spawnMarkers.single;
    expect(marker.enemyId, EnemyId.derf);
    expect(marker.x, 240);
    expect(marker.chancePercent, 75);
    expect(marker.salt, 9);
    expect(marker.placement, SpawnPlacementMode.obstacleTop);
  });

  test('identical source strings yield equivalent immutable products', () {
    PolygonTerrainRuntimeChunkResult compile() =>
        compilePolygonTerrainRuntimeChunkSource(
          prefabSourcePath: 'prefab_defs.json',
          prefabContents: _prefabs,
          tileSourcePath: 'tile_defs.json',
          tileContents: _tiles,
          chunkSourcePath: 'chunk.json',
          chunkContents: _chunk,
        );

    final first = compile().chunk!;
    final second = compile().chunk!;

    expect(
      second.stagedTerrain.authoringPolygonSignature,
      first.stagedTerrain.authoringPolygonSignature,
    );
    expect(
      second.stagedTerrain.sourceSignature,
      first.stagedTerrain.sourceSignature,
    );
    expect(
      second.pattern.visualSprites.single.x,
      first.pattern.visualSprites.single.x,
    );
    expect(
      second.pattern.spawnMarkers.single.enemyId,
      first.pattern.spawnMarkers.single.enemyId,
    );
  });

  test('platform module transforms use the generator flip and scale rules', () {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'prefab_defs.json',
      prefabContents: _modulePrefabs,
      tileSourcePath: 'tile_defs.json',
      tileContents: _moduleTiles,
      chunkSourcePath: 'chunk.json',
      chunkContents: _moduleChunk,
    );

    expect(result.issues, isEmpty);
    final sprite = result.chunk!.pattern.visualSprites.single;
    expect(sprite.assetPath, 'level/tiles.png');
    expect(sprite.x, 76);
    expect(sprite.y, 224);
    expect(sprite.width, 24);
    expect(sprite.height, 24);
    expect(sprite.flipX, isTrue);
    expect(sprite.flipY, isTrue);
  });

  test('missing visual references fail closed with canonical ownership', () {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'prefab_defs.json',
      prefabContents: _prefabs.replaceFirst(
        '"sliceId": "crate"',
        '"sliceId": "missing"',
      ),
      tileSourcePath: 'tile_defs.json',
      tileContents: _tiles,
      chunkSourcePath: 'chunk.json',
      chunkContents: _chunk,
    );

    expect(result.chunk, isNull);
    expect(result.issues.single.code, 'missing_slice');
    expect(result.issues.single.sourcePath, 'chunk.json');
    expect(result.issues.single.ownerKey, 'preview');
  });

  test('missing modules and module slices retain stable issue codes', () {
    PolygonTerrainRuntimeChunkResult compile(String tiles) =>
        compilePolygonTerrainRuntimeChunkSource(
          prefabSourcePath: 'prefab_defs.json',
          prefabContents: _modulePrefabs,
          tileSourcePath: 'tile_defs.json',
          tileContents: tiles,
          chunkSourcePath: 'chunk.json',
          chunkContents: _moduleChunk,
        );

    final missingModule = compile(_tiles);
    expect(missingModule.chunk, isNull);
    expect(missingModule.issues.single.code, 'missing_module');

    final missingSlice = compile(
      _moduleTiles.replaceFirst('"sliceId": "tile"', '"sliceId": "missing"'),
    );
    expect(missingSlice.chunk, isNull);
    expect(missingSlice.issues.single.code, 'missing_tile_slice');
  });

  test('unknown marker fails closed without a partial runtime product', () {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'prefab_defs.json',
      prefabContents: _prefabs,
      tileSourcePath: 'tile_defs.json',
      tileContents: _tiles,
      chunkSourcePath: 'chunk.json',
      chunkContents: _chunk.replaceFirst('"derf"', '"unknown"'),
    );

    expect(result.chunk, isNull);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.code, 'unknown_enemy_marker_id');
  });
}

const String _prefabs = '''
{
  "schemaVersion": 3,
  "slices": [
    {
      "id": "crate",
      "sourceImagePath": "assets/images/level/props.png",
      "x": 2,
      "y": 3,
      "width": 16,
      "height": 20,
      "tags": []
    }
  ],
  "prefabs": [
    {
      "prefabKey": "crate",
      "id": "crate-v1",
      "revision": 1,
      "status": "active",
      "kind": "obstacle",
      "visualSource": {"type": "atlas_slice", "sliceId": "crate"},
      "anchorXPx": 5,
      "anchorYPx": 15,
      "collisionShapes": [],
      "tags": []
    }
  ]
}
''';

const String _tiles = '''
{
  "schemaVersion": 2,
  "tileSlices": [],
  "platformModules": []
}
''';

const String _chunk = '''
{
  "schemaVersion": 2,
  "chunkKey": "preview",
  "id": "preview",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 500,
  "height": 300,
  "difficulty": "normal",
  "assemblyGroupId": "default",
  "tags": [],
  "tileLayers": [],
  "prefabs": [
    {
      "prefabId": "crate-v1",
      "prefabKey": "crate",
      "x": 100,
      "y": 200,
      "zIndex": 4,
      "snapToGrid": false,
      "scale": 1,
      "flipX": false,
      "flipY": false
    }
  ],
  "markers": [
    {
      "markerId": "derf",
      "x": 240,
      "y": 0,
      "chancePercent": 75,
      "salt": 9,
      "placement": "obstacleTop"
    }
  ],
  "collisionShapes": [
    {
      "shapeId": "ground",
      "collisionMode": "solid",
      "vertices": [
        {"x": 0, "y": 240},
        {"x": 500, "y": 240},
        {"x": 500, "y": 300},
        {"x": 0, "y": 300}
      ]
    }
  ]
}
''';

const String _modulePrefabs = '''
{
  "schemaVersion": 3,
  "slices": [],
  "prefabs": [
    {
      "prefabKey": "bridge",
      "id": "bridge-v1",
      "revision": 1,
      "status": "active",
      "kind": "platform",
      "visualSource": {"type": "platform_module", "moduleId": "bridge"},
      "anchorXPx": 16,
      "anchorYPx": 32,
      "collisionShapes": [],
      "tags": []
    }
  ]
}
''';

const String _moduleTiles = '''
{
  "schemaVersion": 2,
  "tileSlices": [
    {
      "id": "tile",
      "sourceImagePath": "assets/images/level/tiles.png",
      "x": 0,
      "y": 0,
      "width": 16,
      "height": 16
    }
  ],
  "platformModules": [
    {
      "id": "bridge",
      "revision": 1,
      "status": "active",
      "tileSize": 16,
      "cells": [{"sliceId": "tile", "gridX": 1, "gridY": 0}]
    }
  ]
}
''';

const String _moduleChunk = '''
{
  "schemaVersion": 2,
  "chunkKey": "module",
  "id": "module",
  "revision": 1,
  "status": "active",
  "levelId": "forest",
  "tileSize": 16,
  "width": 500,
  "height": 300,
  "difficulty": "normal",
  "assemblyGroupId": "default",
  "tags": [],
  "tileLayers": [],
  "prefabs": [
    {
      "prefabId": "bridge-v1",
      "prefabKey": "bridge",
      "x": 100,
      "y": 200,
      "zIndex": 0,
      "snapToGrid": false,
      "scale": 1.5,
      "flipX": true,
      "flipY": true
    }
  ],
  "markers": [],
  "collisionShapes": []
}
''';
