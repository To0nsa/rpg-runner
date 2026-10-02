import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/resource_regen_system.dart';
import 'package:runner_core/ecs/systems/world_interaction_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/interactions/level_blessing.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:test/test.dart';

void main() {
  test('all manual bindings resolve against current generated terrain', () {
    final f = _Fixture();
    for (final binding in WorldInteractionCatalog.bindings) {
      f.world.interactions.synchronize([
        _chunk(0, key: binding.chunkKey),
      ], f.catalog);
      expect(f.world.interactions.states, hasLength(1));
    }
    final state = f.world.interactions.states.single;
    expect(state.leftTicks, 222 * 1024);
    expect(state.rightTicks, 257 * 1024);
    expect(state.topTicks, 160 * 1024);
  });

  for (final invalid in [
    'airborne',
    'side',
    'outside',
    'otherPrefab',
    'staleGeometry',
    'staleTick',
    'dead',
  ]) {
    test('$invalid contact cannot activate the shrine', () {
      final f = _Fixture()..support(tick: 1);
      final c = f.world.terrainContact;
      switch (invalid) {
        case 'airborne':
          c.grounded[0] = false;
        case 'side':
          c.supportNormalYTicks[0] = 0;
        case 'outside':
          c.supportPointXTicks[0] = 258 * 1024;
        case 'otherPrefab':
          c.supportEdgeId[0] = TerrainEdgeId(
            chunkIndex: 0,
            chunkKey: 'forest_early_hill_001',
            shapeId: 'collision_001',
            placementKey: 'other',
            localEdgeIndex: 0,
          );
        case 'staleGeometry':
          c.supportGeometryVersion[0] = 2;
        case 'staleTick':
          c.lastValidSupportTick[0] = 0;
        case 'dead':
          f.world.health.hp[0] = 0;
      }
      f.step(1);
      expect(f.world.interactions.states.single.activationTick, isNull);
      expect(f.world.levelBlessings.snapshots(f.player), isEmpty);
    });
  }

  test('enemy support does not activate; player support grants once', () {
    final f = _Fixture();
    final enemy = f.world.createEntity();
    f.world.terrainContact.add(enemy);
    f.support(entity: enemy, tick: 1);
    f.step(1);
    expect(f.world.levelBlessings.snapshots(f.player), isEmpty);
    f.support(tick: 2);
    f.step(2);
    final grant = f.world.levelBlessings.snapshots(f.player).single;
    expect(grant.id, LevelBlessingId.regeneration);
    expect(grant.grantedAtTick, 2);
    f.support(tick: 3);
    f.step(3);
    expect(f.world.levelBlessings.snapshots(f.player).single.grantedAtTick, 2);
    expect(f.world.levelBlessings.healthRegen100.single, 5);
  });

  for (final hz in [30, 60, 120]) {
    test(
      'flat bonuses accumulate exactly at $hz Hz, including zero base regen',
      () {
        final f = _Fixture()..support(tick: 1);
        f.step(1);
        final regen = ResourceRegenSystem(tickHz: hz);
        for (var i = 0; i < hz * 10; i++) {
          regen.step(f.world);
        }
        expect(f.world.health.hp.single, 5050);
        expect(f.world.mana.mana.single, 5200);
        expect(f.world.stamina.stamina.single, 5100);
        expect(f.world.health.regenPerSecond100.single, 0);
        f.world.health.hp[0] = 9999;
        f.world.mana.mana[0] = 9999;
        f.world.stamina.stamina[0] = 9999;
        for (var i = 0; i < hz; i++) {
          regen.step(f.world);
        }
        expect(f.world.health.hp.single, 10000);
        expect(f.world.mana.mana.single, 10000);
        expect(f.world.stamina.stamina.single, 10000);
      },
    );
  }

  test(
    'stream retirement preserves bonus, reentry state, and occurrence identity',
    () {
      final f = _Fixture()..support(tick: 1);
      f.step(1);
      f.world.interactions.synchronize([], f.catalog);
      expect(f.world.interactions.buildSnapshots(), isEmpty);
      expect(f.world.levelBlessings.snapshots(f.player), hasLength(1));
      for (var i = 0; i < 60; i++) {
        ResourceRegenSystem(tickHz: 60).step(f.world);
      }
      expect(f.world.health.hp.single, 5005);
      f.world.interactions.synchronize([_chunk(0), _chunk(1)], f.catalog);
      expect(f.world.interactions.states[0].activationTick, 1);
      expect(f.world.interactions.states[1].activationTick, isNull);
      f.support(tick: 100, stateIndex: 1);
      f.step(100);
      expect(f.world.interactions.states[1].activationTick, 100);
      expect(f.world.levelBlessings.healthRegen100.single, 5);
      expect(
        f.world.levelBlessings.snapshots(f.player).single.grantedAtTick,
        1,
      );
      expect(_Fixture().world.levelBlessings.snapshots(1), isEmpty);
      expect(
        _Fixture().world.interactions.states.single.activationTick,
        isNull,
      );
    },
  );

  test('entity teardown removes bonuses before entity reuse', () {
    final f = _Fixture()..support(tick: 1);
    f.step(1);
    final other = f.world.createEntity();
    f.world.levelBlessings.grant(other, LevelBlessingId.regeneration, tick: 2);
    f.world.destroyEntity(f.player);
    expect(f.world.levelBlessings.snapshots(f.player), isEmpty);
    expect(f.world.levelBlessings.snapshots(other).single.grantedAtTick, 2);
    expect(f.world.levelBlessings.healthRegen100, [5]);
  });

  test(
    'missing binding fails without replacing the admitted active collection',
    () {
      final f = _Fixture();
      expect(
        () => f.world.interactions.synchronize(
          [_chunk(0)],
          f.catalog,
          bindings: [
            const WorldInteractionBinding(
              key: 'missing',
              chunkKey: 'forest_early_hill_001',
              prefabKey: 'missing',
              shapeId: 'collision_001',
              interactionId: WorldInteractionId.regenerationShrine,
            ),
          ],
        ),
        throwsStateError,
      );
      expect(
        f.world.interactions.states.single.binding.key,
        'forest_regeneration_vasque',
      );
    },
  );
}

ActiveTrackChunkSnapshot _chunk(
  int index, {
  String key = 'forest_early_hill_001',
}) => ActiveTrackChunkSnapshot(
  index: index,
  startX: index * 600.0,
  endX: (index + 1) * 600.0,
  patternName: key,
  chunkKey: key,
);

class _Fixture {
  _Fixture() {
    world.health.add(
      player,
      const HealthDef(hp: 5000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.mana.add(
      player,
      const ManaDef(mana: 5000, manaMax: 10000, regenPerSecond100: 0),
    );
    world.stamina.add(
      player,
      const StaminaDef(stamina: 5000, staminaMax: 10000, regenPerSecond100: 0),
    );
    world.terrainContact.add(player);
    world.interactions.synchronize([_chunk(0)], catalog);
  }
  final world = EcsWorld();
  late final player = world.createEntity();
  final catalog = StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain);

  void support({required int tick, int? entity, int stateIndex = 0}) {
    final state = world.interactions.states[stateIndex];
    final c = world.terrainContact;
    final i = c.indexOf(entity ?? player);
    c.grounded[i] = true;
    c.supportGeometryVersion[i] = 1;
    c.lastValidSupportTick[i] = tick;
    c.supportNormalYTicks[i] = -1024;
    c.supportPointXTicks[i] = (state.leftTicks + state.rightTicks) ~/ 2;
    c.supportPointYTicks[i] = state.topTicks;
    c.supportEdgeId[i] = TerrainEdgeId(
      chunkIndex: state.chunkIndex,
      chunkKey: state.binding.chunkKey,
      placementKey: state.placementKey,
      shapeId: state.binding.shapeId,
      localEdgeIndex: 0,
    );
  }

  void step(int tick) => const WorldInteractionSystem().step(
    world,
    player: player,
    tick: tick,
    geometryVersion: 1,
  );
}
