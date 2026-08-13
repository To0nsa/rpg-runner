import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/characters/eloise_wip.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:test/test.dart';

void main() {
  test('both Éloïse definitions derive the frozen capsule and exact AABB', () {
    final definitions = [eloiseCharacter, eloiseWipCharacter];

    for (final definition in definitions) {
      final derived = PlayerCatalogDerived.from(
        definition.catalog,
        movement: MovementTuningDerived.from(
          definition.tuning.movement,
          tickHz: 60,
        ),
        resources: ResourceTuningDerived.from(definition.tuning.resource),
      ).archetype;
      final capsule = derived.worldContactCapsule;
      final aabb = capsule.derivedAabb;

      expect(capsule.radius, 9.65);
      expect(capsule.verticalHalfSegment, 12.85);
      expect(capsule.offsetX, 0.35);
      expect(capsule.offsetY, 1.5);
      expect(aabb.halfX, 9.65);
      expect(aabb.halfY, 22.5);
      expect(aabb.offsetX, 0.35);
      expect(aabb.offsetY, 1.5);
      expect(derived.collider.halfX, aabb.halfX);
      expect(derived.collider.halfY, aabb.halfY);
      expect(derived.collider.offsetX, aabb.offsetX);
      expect(derived.collider.offsetY, aabb.offsetY);
    }
  });

  test('authoring quantizes once and facing mirrors only the X offset', () {
    final definition = WorldContactCapsuleDef(
      radius: 10.3,
      verticalHalfSegment: 12.7,
      offsetX: -0.3,
      offsetY: 1,
    );
    final body = TerrainPoint.fromWorld(100, 200);
    final right = UprightCapsule.fromBody(
      bodyCenter: body,
      facing: TerrainFacing.right,
      offsetXTicks: definition.offsetXTicks,
      offsetYTicks: definition.offsetYTicks,
      radiusTicks: definition.radiusTicks,
      verticalHalfSegmentTicks: definition.verticalHalfSegmentTicks,
    );
    final left = UprightCapsule.fromBody(
      bodyCenter: body,
      facing: TerrainFacing.left,
      offsetXTicks: definition.offsetXTicks,
      offsetYTicks: definition.offsetYTicks,
      radiusTicks: definition.radiusTicks,
      verticalHalfSegmentTicks: definition.verticalHalfSegmentTicks,
    );

    expect(right.center.xTicks, body.xTicks + definition.offsetXTicks);
    expect(left.center.xTicks, body.xTicks - definition.offsetXTicks);
    expect(right.center.yTicks, body.yTicks + definition.offsetYTicks);
    expect(left.center.yTicks, right.center.yTicks);
    expect(right.bounds.minX, right.center.xTicks - definition.radiusTicks);
    expect(right.bounds.maxX, right.center.xTicks + definition.radiusTicks);
    expect(
      right.bounds.minY,
      right.center.yTicks -
          definition.radiusTicks -
          definition.verticalHalfSegmentTicks,
    );
    expect(
      right.bounds.maxY,
      right.center.yTicks +
          definition.radiusTicks +
          definition.verticalHalfSegmentTicks,
    );
  });

  test('definition rejects invalid dimensions and conversion overflow', () {
    expect(
      () => WorldContactCapsuleDef(radius: 0, verticalHalfSegment: 1),
      throwsArgumentError,
    );
    expect(
      () => WorldContactCapsuleDef(radius: 1, verticalHalfSegment: -1),
      throwsArgumentError,
    );
    expect(
      () => WorldContactCapsuleDef(
        radius: 1,
        verticalHalfSegment: 0,
        offsetX: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => WorldContactCapsuleDef(radius: 1e20, verticalHalfSegment: 0),
      throwsRangeError,
    );
  });

  test('circle degeneration and ECS swap removal preserve tick values', () {
    final world = EcsWorld();
    final first = world.createEntity();
    final second = world.createEntity();
    final circle = WorldContactCapsuleDef(radius: 8, verticalHalfSegment: 0);
    final capsule = WorldContactCapsuleDef(
      radius: 10,
      verticalHalfSegment: 12,
      offsetX: 1,
      offsetY: 2,
    );

    world.worldContactCapsule.add(first, circle);
    world.worldContactCapsule.add(second, capsule);
    world.destroyEntity(first);

    final index = world.worldContactCapsule.indexOf(second);
    expect(world.worldContactCapsule.radiusTicks[index], 10 * 1024);
    expect(
      world.worldContactCapsule.verticalHalfSegmentTicks[index],
      12 * 1024,
    );
    expect(world.worldContactCapsule.offsetXTicks[index], 1024);
    expect(world.worldContactCapsule.offsetYTicks[index], 2 * 1024);
  });

  test(
    'resolved motion retains gravity as a separate request contribution',
    () {
      final world = EcsWorld();
      final entity = world.createEntity();
      world.resolvedMotion.add(entity);
      final request = TerrainMotionRequest(
        displacementXTicks: 100,
        displacementYTicks: -20,
        gravityYTicks: 30,
        mode: TerrainMotionMode.groundedHorizontal,
      );

      world.resolvedMotion.beginTick(
        entity,
        capsuleCenterXTicks: 1000,
        capsuleCenterYTicks: 2000,
        request: request,
      );
      world.resolvedMotion.setResolved(
        entity,
        displacementXTicks: 100,
        displacementYTicks: -50,
        travelAlongSupportTicks: 112,
      );

      final index = world.resolvedMotion.indexOf(entity);
      expect(request.composedXTicks, 100);
      expect(request.composedYTicks, 10);
      expect(world.resolvedMotion.gravityYTicks[index], 30);
      expect(world.resolvedMotion.resolvedXTicks[index], 100);
      expect(world.resolvedMotion.supportedTravelTicks[index], 112);
    },
  );
}
