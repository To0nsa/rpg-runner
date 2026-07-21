import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/ecs/world_support_view.dart';
import 'package:test/test.dart';

void main() {
  test('legacy entities continue reading CollisionStateStore', () {
    final world = EcsWorld();
    final entity = world.createEntity();
    world.collision.add(entity);
    world.collision.grounded[world.collision.indexOf(entity)] = true;

    final view = WorldSupportView(world);

    expect(view.usesTerrainContact(entity), isFalse);
    expect(view.isGrounded(entity), isTrue);
  });

  test('terrain component selects versioned support over legacy flags', () {
    final world = EcsWorld();
    final entity = world.createEntity();
    world.collision.add(entity);
    world.collision.grounded[world.collision.indexOf(entity)] = true;
    world.terrainContact.add(entity);
    final edge = _flatEdge();
    world.terrainContact.setSupport(
      entity,
      edge: edge,
      pointXTicks: 0,
      pointYTicks: 10 * 1024,
      geometryVersion: 3,
      currentTick: 9,
    );
    final view = WorldSupportView(world);

    expect(view.usesTerrainContact(entity), isTrue);
    expect(view.isGrounded(entity, geometryVersion: 3), isTrue);
    expect(view.supportEdgeId(entity, geometryVersion: 3), edge.id);
    expect(view.isGrounded(entity, geometryVersion: 4), isFalse);
    expect(view.supportEdgeId(entity, geometryVersion: 4), isNull);

    world.terrainContact.beginTick(entity, currentGeometryVersion: 4);
    final index = world.terrainContact.indexOf(entity);
    expect(world.terrainContact.grounded[index], isFalse);
    expect(world.terrainContact.supportEdgeId[index], isNull);
    expect(world.terrainContact.snapEligibleAtTickStart[index], isFalse);
  });
}

TerrainEdge _flatEdge() {
  final id = TerrainEdgeId(
    chunkIndex: 0,
    chunkKey: 'test',
    shapeId: 'floor',
    localEdgeIndex: 0,
  );
  return TerrainEdge(
    id: id,
    start: TerrainPoint(0, 10 * 1024),
    end: TerrainPoint(20 * 1024, 10 * 1024),
    tangent: TerrainDirection(1024, 0),
    outwardNormal: TerrainDirection(0, -1024),
    collisionMode: TerrainCollisionMode.solid,
    surfaceKind: null,
    materialKey: null,
    previousId: null,
    nextId: null,
    startJoin: TerrainVertexJoin.exposed,
    endJoin: TerrainVertexJoin.exposed,
    bounds: TerrainAabb(
      minX: 0,
      minY: 10 * 1024,
      maxX: 20 * 1024,
      maxY: 10 * 1024,
    ),
  );
}
