import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_queries.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cached bounds preserve exact containment for concave and sloped loops',
    () {
      final loops = <List<(double, double)>>[
        [(-12, -10), (20, -10), (20, 18), (-12, 18)],
        [(-10, -8), (30, 12), (-10, 12)],
        [(-12, -10), (20, -10), (20, 18), (8, 18), (8, 2), (-12, 2)],
      ];
      for (var index = 0; index < loops.length; index++) {
        final geometry = const TerrainCompiler().compile([
          TerrainPolygonInput.fromWorld(
            sourcePath: 'test/$index',
            identity: TerrainSourceIdentity(
              chunkIndex: 0,
              chunkKey: 'fixture',
              shapeId: 'shape',
            ),
            vertices: loops[index],
          ),
        ], geometryVersion: 1);
        final polygon = geometry.polygons.single;
        for (var x = -16; x <= 34; x++) {
          for (var y = -14; y <= 22; y++) {
            final point = TerrainPoint.fromWorld(x.toDouble(), y.toDouble());
            expect(
              polygon.containsPointStrictly(point),
              terrainPointStrictlyInsidePolygon(point, polygon.vertices),
              reason: 'loop=$index point=$point',
            );
          }
        }
        for (final point in polygon.vertices) {
          expect(polygon.containsPointStrictly(point), isFalse);
        }
      }
    },
  );
}
