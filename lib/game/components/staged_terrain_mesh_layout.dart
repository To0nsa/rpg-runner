import 'dart:ui';

import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/snapshots/staged_terrain_render_snapshot.dart';

/// Immutable UI mesh retaining Core's exact polygon loop and triangle order.
final class StagedTerrainMeshData {
  StagedTerrainMeshData({
    required this.sourceId,
    required this.materialKey,
    required Iterable<Offset> positions,
    required Iterable<int> triangleIndices,
  }) : positions = List<Offset>.unmodifiable(positions),
       triangleIndices = List<int>.unmodifiable(triangleIndices);

  final TerrainSourceIdentity sourceId;
  final String materialKey;
  final List<Offset> positions;
  final List<int> triangleIndices;
}

/// Converts Core physics units to draw units without deriving new geometry.
abstract final class StagedTerrainMeshLayout {
  static List<StagedTerrainMeshData> build(
    StagedTerrainRenderSnapshot snapshot,
  ) {
    final meshes = <StagedTerrainMeshData>[];
    for (final polygon in snapshot.polygons) {
      final materialKey = polygon.materialKey;
      if (materialKey == null) continue;
      final positions = <Offset>[
        for (final vertex in polygon.vertices)
          Offset(
            vertex.xTicks / terrainPhysicsTicksPerWorldUnit,
            vertex.yTicks / terrainPhysicsTicksPerWorldUnit,
          ),
      ];
      final triangleIndices = <int>[];
      for (final triangle in polygon.triangles) {
        final indices = <int>[triangle.first, triangle.second, triangle.third];
        for (final index in indices) {
          if (index < 0 || index >= positions.length) {
            throw StateError(
              'Terrain render triangle for ${polygon.sourceId} references '
              'vertex $index outside ${positions.length} positions.',
            );
          }
        }
        triangleIndices.addAll(indices);
      }
      meshes.add(
        StagedTerrainMeshData(
          sourceId: polygon.sourceId,
          materialKey: materialKey,
          positions: positions,
          triangleIndices: triangleIndices,
        ),
      );
    }
    return List<StagedTerrainMeshData>.unmodifiable(meshes);
  }
}
