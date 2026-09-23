import 'package:runner_core/collision/terrain/terrain_chunk_connections.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test('Chunk Play keeps the preferred landing when it is clear', () {
    expect(
      findTerrainChunkPlaytestStartX(
        chunkKey: 'chunk',
        chunkWidth: 100,
        geometry: _geometry(const <(double, double)>[
          (0, 80),
          (100, 80),
          (100, 100),
          (0, 100),
        ]),
        groundTopY: 80,
        preferredX: 50,
      ),
      50,
    );
  });

  test('Chunk Play finds the nearest clear landing after a gap', () {
    final geometry = const TerrainCompiler().compile(<TerrainPolygonInput>[
      _polygon('left', const <(double, double)>[
        (0, 80),
        (40, 80),
        (40, 100),
        (0, 100),
      ]),
      _polygon('right', const <(double, double)>[
        (60, 80),
        (100, 80),
        (100, 100),
        (60, 100),
      ]),
    ], geometryVersion: 1);
    expect(
      buildTerrainChunkConnection(
        chunkKey: 'chunk',
        chunkWidth: 100,
        geometry: geometry,
        groundTopY: 80,
        spawnX: 50,
      ).canStart,
      isFalse,
    );
    expect(
      findTerrainChunkPlaytestStartX(
        chunkKey: 'chunk',
        chunkWidth: 100,
        geometry: geometry,
        groundTopY: 80,
        preferredX: 50,
      ),
      76,
    );
  });

  test('alternate landing still requires the normal ground entrance', () {
    expect(
      findTerrainChunkPlaytestStartX(
        chunkKey: 'chunk',
        chunkWidth: 100,
        geometry: _geometry(const <(double, double)>[
          (10, 80),
          (100, 80),
          (100, 100),
          (10, 100),
        ]),
        groundTopY: 80,
        preferredX: 50,
      ),
      isNull,
    );
  });

  test('alternate landing fails when no full player-width support exists', () {
    expect(
      findTerrainChunkPlaytestStartX(
        chunkKey: 'chunk',
        chunkWidth: 100,
        geometry: _geometry(const <(double, double)>[
          (0, 80),
          (20, 80),
          (20, 100),
          (0, 100),
        ]),
        groundTopY: 80,
        preferredX: 50,
      ),
      isNull,
    );
  });
}

TerrainPolygonInput _polygon(String shapeId, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'chunks/chunk.json#$shapeId',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: shapeId,
      ),
      vertices: vertices,
    );

TerrainGeometry _geometry(List<(double, double)> vertices) =>
    const TerrainCompiler().compile(<TerrainPolygonInput>[
      _polygon('ground', vertices),
    ], geometryVersion: 1);
