import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/ecs/collider_aabb_utils.dart';
import 'package:runner_core/bosses/boss_resource_supply_definition.dart';
import 'package:runner_core/bosses/boss_resource_supply_spawn_adapter.dart';
import 'package:runner_core/bosses/boss_resource_supply_system.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/restoration_item_store.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/spawn_service.dart';
import 'package:runner_core/tuning/collectible_tuning.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/restoration_item_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

import '../test_support/goddess_combat_fixture.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final (obstacle, expectedX) in <(String?, double)>[
      (null, 64),
      ('wall', -64),
      ('gap', -64),
      ('ceiling', 64),
    ]) {
      test(
        'supply is walkable on current support with $obstacle at $hz Hz',
        () {
          final f = GoddessCombatFixture(hz: hz, blocked: obstacle);
          final adapter = _adapter(f);
          final beforeX =
              f.world.transform.posX[f.world.transform.indexOf(f.player)];
          final beforeY =
              f.world.transform.posY[f.world.transform.indexOf(f.player)];
          final item = adapter.spawn(
            f.world,
            player: f.player,
            encounter: _encounter(f),
            stat: RestorationStat.mana,
          );
          expect(item, isNotNull);
          final ti = f.world.transform.indexOf(item!);
          final pi = f.world.worldContactCapsule.indexOf(f.player);
          final centerX =
              beforeX +
              f.world.worldContactCapsule.offsetXTicks[pi] *
                  colliderFacingSign(f.world, f.player) /
                  terrainPhysicsTicksPerWorldUnit;
          expect(f.world.transform.posX[ti], centerX + expectedX);
          final contactIndex = f.world.terrainContact.indexOf(f.player);
          final supportY =
              f.world.terrainContact.supportPointYTicks[contactIndex] /
              terrainPhysicsTicksPerWorldUnit;
          expect(f.world.transform.posY[ti], supportY - 18);
          expect(f.world.restorationItem.stat.single, RestorationStat.mana);
          expect(
            f.world.transform.posX[f.world.transform.indexOf(f.player)],
            beforeX,
          );
          expect(
            f.world.transform.posY[f.world.transform.indexOf(f.player)],
            beforeY,
          );
        },
      );
    }
  }

  test('no spawn beyond arena boundaries or on stale/airborne support', () {
    final f = GoddessCombatFixture();
    final adapter = _adapter(f);
    int? spawn({double minX = 24, double maxX = 600}) => adapter.spawn(
      f.world,
      player: f.player,
      encounter: _encounter(f, minX: minX, maxX: maxX),
      stat: RestorationStat.stamina,
    );
    expect(spawn(minX: 280, maxX: 320), isNull);
    final ci = f.world.terrainContact.indexOf(f.player);
    f.world.terrainContact.supportGeometryVersion[ci] = -1;
    expect(spawn(), isNull);
    f.world.terrainContact.supportGeometryVersion[ci] =
        f.motion.terrainRuntimeBundle.version;
    f.world.terrainContact.grounded[ci] = false;
    expect(spawn(), isNull);
    f.world.terrainContact.grounded[ci] = true;
    expect(spawn(), isNotNull);
  });
}

BossResourceSupplyEncounter _encounter(
  GoddessCombatFixture f, {
  double minX = 24,
  double maxX = 600,
}) => BossResourceSupplyEncounter(
  occurrence: 3,
  boss: f.boss,
  minX: minX,
  maxX: maxX,
  definition: const BossResourceSupplyDefinition(healthThresholdBp: 5000),
);

BossResourceSupplySpawnAdapter _adapter(GoddessCombatFixture f) {
  final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: f.hz,
  );
  final player = PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: movement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;
  final spawns = SpawnService(
    world: f.world,
    entityFactory: EntityFactory(f.world),
    enemyCatalog: const EnemyCatalog(),
    movement: movement,
    unocoDemonTuning: UnocoDemonTuningDerived.from(
      const UnocoDemonTuning(),
      tickHz: f.hz,
    ),
    collectibleTuning: const CollectibleTuning(),
    restorationItemTuning: const RestorationItemTuning(),
    trackTuning: const TrackTuning(),
    worldMotionAuthority: f.motion,
    playerTerrainTraversalProfile: player.terrainTraversalProfile,
    seed: 41,
  );
  return BossResourceSupplySpawnAdapter(
    motion: f.motion,
    runtimeBundle: () => f.motion.terrainRuntimeBundle,
    spawns: spawns,
    playerProfile: player.terrainTraversalProfile,
    tuning: const RestorationItemTuning(),
  );
}
