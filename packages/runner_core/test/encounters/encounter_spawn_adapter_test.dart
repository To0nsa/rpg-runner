import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_instance.dart';
import 'package:runner_core/encounters/encounter_spawn_adapter.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/spawn_service.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/tuning/collectible_tuning.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/restoration_item_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  test(
    'preflights and creates all four required enemy types at authored X',
    () {
      final h = _Harness();
      final result = h.adapter.spawn(_occurrence(), tick: 20);
      expect(result, isA<EncounterSpawned>());
      final entities = (result as EncounterSpawned).entities;
      expect(entities.keys, ['derf', 'grojib', 'hashash', 'unoco', 'warrior']);
      expect(h.world.npc.denseEntities, [entities['warrior']]);
      expect(h.world.enemy.denseEntities, hasLength(4));
      final hashash = entities['hashash']!;
      expect(h.world.transform.posX[h.world.transform.indexOf(hashash)], 300);
      expect(h.world.hashashTeleport.has(hashash), isTrue);
      expect(
        h.world.spawnState.startTick[h.world.spawnState.indexOf(hashash)],
        20,
      );
      expect(h.world.controlLock.isLocked(hashash, LockFlag.move, 20), isTrue);
    },
  );

  test(
    'one rejected required member creates no partial actors or recycled IDs',
    () {
      final h = _Harness();
      final result = h.adapter.spawn(_occurrence(invalidDerf: true), tick: 20);
      expect(result, isA<EncounterSpawnRejected>());
      expect(h.world.health.denseEntities, isEmpty);
      expect(h.world.npc.denseEntities, isEmpty);
      expect(h.world.enemy.denseEntities, isEmpty);
      expect(h.world.createEntity(), EcsWorld().createEntity());
    },
  );
}

EncounterOccurrence _occurrence({
  bool invalidDerf = false,
}) => EncounterOccurrence(
  chunkIndex: 0,
  startX: 0,
  endX: 600,
  definition: EncounterDefinition(
    id: 'complete',
    name: 'Complete roster',
    trigger: EncounterTrigger(x: 0, y: -200, width: 600, height: 500),
    npcs: [EncounterNpcPlacement(id: 'warrior', npcId: NpcId.warrior, x: 100)],
    enemies: [
      EncounterEnemyPlacement(id: 'grojib', enemyId: EnemyId.grojib, x: 200),
      EncounterEnemyPlacement(id: 'hashash', enemyId: EnemyId.hashash, x: 300),
      EncounterEnemyPlacement(id: 'unoco', enemyId: EnemyId.unocoDemon, x: 380),
      EncounterEnemyPlacement(
        id: 'derf',
        enemyId: EnemyId.derf,
        x: 500,
        placement: invalidDerf
            ? SpawnPlacementMode.ground
            : SpawnPlacementMode.obstacleTop,
      ),
    ],
  ),
);

class _Harness {
  final world = EcsWorld(seed: 7);
  late final EncounterSpawnAdapter adapter;
  _Harness() {
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final player = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;
    final geometry = const TerrainCompiler().compile([
      _rectangle('ground', -1000, 200, 2000, 400, 'ground'),
      _rectangle('platform', 420, 120, 590, 200, 'obstacle'),
    ], geometryVersion: 1);
    final motion = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: player.terrainTraversalProfile,
    );
    final spawns = SpawnService(
      world: world,
      entityFactory: EntityFactory(world),
      enemyCatalog: const EnemyCatalog(),
      movement: movement,
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
      collectibleTuning: const CollectibleTuning(),
      restorationItemTuning: const RestorationItemTuning(),
      trackTuning: const TrackTuning(),
      worldMotionAuthority: motion,
      playerTerrainTraversalProfile: player.terrainTraversalProfile,
      seed: 7,
    );
    adapter = EncounterSpawnAdapter(
      world: world,
      motion: motion,
      spawns: spawns,
      groundTopY: 200,
      flyingHoverOffsetY: 140,
    );
  }
}

TerrainPolygonInput _rectangle(
  String id,
  double left,
  double top,
  double right,
  double bottom,
  String kind,
) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$id',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'fixture',
    shapeId: id,
  ),
  vertices: [(left, top), (right, top), (right, bottom), (left, bottom)],
  surfaceKind: kind,
);
