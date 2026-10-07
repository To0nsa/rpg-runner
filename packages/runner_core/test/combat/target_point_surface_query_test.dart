import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/target_point_surface_query.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

void main() {
  test('captures floor, one-way platform and airborne target support', () {
    final index = _index([
      _polygon('floor', [(0, 224), (600, 224), (600, 300), (0, 300)]),
      _polygon('platform', [
        (167, 133),
        (263, 133),
        (263, 143),
        (167, 143),
      ], oneWay: true),
    ]);
    final query = TargetPointSurfaceQuery(() => index);
    expect(query.below(100, 200), const Vec2(100, 224));
    expect(query.below(215, 110), const Vec2(215, 133));
    expect(query.below(215, 0), const Vec2(215, 133));
    expect(query.below(215, 150), const Vec2(215, 224));
    expect(query.below(215, 133), const Vec2(215, 133));
    expect(query.below(650, 0), isNull);
    expect(query.below(100, 250), isNull);
  });

  test('samples exact slope height instead of an endpoint or flat ground', () {
    final index = _index([
      _polygon('slope', [(0, 120), (300, 180), (300, 300), (0, 300)]),
    ]);
    final query = TargetPointSurfaceQuery(() => index);
    expect(query.below(150, 0), const Vec2(150, 150));
    expect(query.below(0, 0), const Vec2(0, 120));
    expect(query.below(300, 0), const Vec2(300, 180));
  });

  test(
    'new terrain publication updates surface scratch and vertical bounds',
    () {
      var index = _index([
        _polygon('floor', [(0, 224), (600, 224), (600, 300), (0, 300)]),
      ]);
      final query = TargetPointSurfaceQuery(() => index);
      final captured = query.below(200, 0);
      expect(captured, const Vec2(200, 224));
      index = _index([
        _polygon('floor', [(0, 400), (600, 400), (600, 500), (0, 500)]),
      ], version: 2);
      expect(query.below(200, 0), const Vec2(200, 400));
      expect(captured, const Vec2(200, 224));
      index = _index(const [], version: 3);
      expect(query.below(200, 0), isNull);
    },
  );
}

TerrainSurfaceSpatialIndex _index(
  List<TerrainPolygonInput> polygons, {
  int version = 1,
}) {
  final geometry = const TerrainCompiler().compile(
    polygons,
    geometryVersion: version,
  );
  return TerrainSurfaceSpatialIndex(
    surfaceSet: const TerrainSurfaceExtractor().extract(geometry),
  );
}

TerrainPolygonInput _polygon(
  String id,
  List<(double, double)> vertices, {
  bool oneWay = false,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$id',
  identity: TerrainSourceIdentity(chunkIndex: 0, chunkKey: 'test', shapeId: id),
  collisionMode: oneWay
      ? TerrainCollisionMode.oneWay
      : TerrainCollisionMode.solid,
  vertices: vertices,
);
