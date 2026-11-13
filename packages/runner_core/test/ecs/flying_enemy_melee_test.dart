import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/combat_hurtbox_system.dart';
import 'package:runner_core/ecs/systems/cooldown_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/flying_enemy_combat_mode_system.dart';
import 'package:runner_core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/flying_enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/invulnerability_system.dart';
import 'package:runner_core/ecs/systems/lifetime_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/resource_regen_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final character in PlayerCharacterRegistry.playable) {
      for (final side in [-1, 0, 1]) {
        for (final regenerate in [false, true]) {
          test('Unoco melee hits idle ${character.id.name} from side=$side '
              'regen=$regenerate at $hz Hz', () {
            final f = _Fixture(hz, character, side, regenerate: regenerate);
            final initialHp = f.hp;
            (double, double, Facing)? committedPose;
            for (var tick = 1; tick <= 5 * hz; tick++) {
              f.step(tick);
              if (f.activeAbility == 'unoco.strike') {
                committedPose ??= f.enemyPose;
                expect(
                  f.enemyPose,
                  committedPose,
                  reason: 'hold through recovery',
                );
              } else if (committedPose != null) {
                break;
              }
            }
            expect(
              committedPose,
              isNotNull,
              reason: 'the approach must reach contact',
            );
            expect(f.hp, lessThan(initialHp), reason: f.trace.join('\n'));
            expect(f.meleeHits, 1);
            if (regenerate) {
              expect(f.activeAbility, 'unoco.fire_bolt_cast');
            }
          });
        }
      }
    }
  }

  for (final hz in [30, 60, 90]) {
    test('Unoco strike can be evaded during windup at $hz Hz', () {
      final f = _Fixture(
        hz,
        PlayerCharacterRegistry.eloise,
        1,
        regenerate: true,
      );
      var tick = 0;
      while (f.activeAbility != 'unoco.strike' && tick < 5 * hz) {
        f.step(++tick);
      }
      expect(f.activeAbility, 'unoco.strike');
      final initialHp = f.hp;
      // The player moves continuously away during the telegraph; the strike
      // must not track or relocate to guarantee a hit against an evading target.
      while (f.activeAbility == 'unoco.strike' && tick < 6 * hz) {
        final pi = f.world.transform.indexOf(f.player);
        f.world.transform.velX[pi] = -300;
        f.step(++tick);
      }
      expect(f.hp, initialHp);
      expect(f.meleeHits, 0);
      expect(f.activeAbility, 'unoco.fire_bolt_cast');
    });
  }
}

class _Fixture {
  _Fixture(
    this.hz,
    PlayerCharacterDefinition character,
    int side, {
    required bool regenerate,
  }) {
    movement = MovementTuningDerived.from(
      character.tuning.movement,
      tickHz: hz,
    );
    final playerArchetype = PlayerCatalogDerived.from(
      character.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(character.tuning.resource),
    ).archetype;
    final factory = EntityFactory(world);
    player = factory.createPlayer(
      posX: 500,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: _flatTerrain,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    final playerY = world.transform.posY[world.transform.indexOf(player)];
    final a = const EnemyCatalog().get(EnemyId.unocoDemon);
    enemy = factory.createEnemy(
      enemyId: EnemyId.unocoDemon,
      posX: 500 + side * 200,
      posY: playerY - 100,
      velX: 0,
      velY: 0,
      facing: side < 0 ? Facing.right : Facing.left,
      artFacing: a.artFacingDir,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
    final mi = world.mana.indexOf(enemy);
    // Force the real mana-based fallback; a short deficit can regenerate
    // during the approach, before the latched strike has reached its target.
    world.mana.mana[mi] = regenerate ? 2400 : 0;
    world.mana.regenPerSecond100[mi] = regenerate
        ? a.mana.regenPerSecond100
        : 0;
    final tuning = UnocoDemonTuningDerived.from(
      const UnocoDemonTuning(),
      tickHz: hz,
    );
    locomotion = FlyingEnemyLocomotionSystem(
      unocoDemonTuning: tuning,
      worldMotionAuthority: authority,
    );
    melee = FlyingEnemyMeleeSystem(unocoDemonTuning: tuning);
    follow = HitboxFollowOwnerSystem(
      tickHz: hz,
      playerRenderAnim: character.renderAnim,
    );
    anim = AnimSystem(
      tickHz: hz,
      playerRenderAnim: character.renderAnim,
      enemyCatalog: const EnemyCatalog(),
      playerMovement: movement,
      playerAnimTuning: AnimTuningDerived.from(
        character.tuning.anim,
        tickHz: hz,
      ),
    );
    hurtboxes = CombatHurtboxSystem(
      tickHz: hz,
      playerRenderAnim: character.renderAnim,
      playerCharacterId: character.id,
    );
    cast = EnemyCastSystem(
      unocoDemonTuning: tuning,
      enemyCatalog: const EnemyCatalog(),
      projectiles: const ProjectileCatalog(),
    );
    regen = ResourceRegenSystem(tickHz: hz);
    damage = DamageSystem(
      invulnerabilityTicksOnHit: hz ~/ 4,
      rngSeed: 7,
      tickHz: hz,
    );
  }

  final int hz;
  final world = EcsWorld(seed: 7);
  late final int player;
  late final int enemy;
  late final MovementTuningDerived movement;
  late final TerrainMultiBodyWorldMotionAuthority authority;
  late final FlyingEnemyLocomotionSystem locomotion;
  late final FlyingEnemyMeleeSystem melee;
  late final HitboxFollowOwnerSystem follow;
  late final AnimSystem anim;
  late final CombatHurtboxSystem hurtboxes;
  late final EnemyCastSystem cast;
  late final ResourceRegenSystem regen;
  late final DamageSystem damage;
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
  final modes = FlyingEnemyCombatModeSystem();
  final cooldown = CooldownSystem();
  final phase = ActiveAbilityPhaseSystem();
  final strikes = MeleeStrikeSystem();
  final hits = HitboxDamageSystem();
  final invulnerability = InvulnerabilitySystem();
  final lifetime = LifetimeSystem();
  final trace = <String>[];
  int meleeHits = 0;

  int get hp => world.health.hp[world.health.indexOf(player)];
  String? get activeAbility =>
      world.activeAbility.abilityId[world.activeAbility.indexOf(enemy)];
  (double, double, Facing) get enemyPose => (
    world.transform.posX[world.transform.indexOf(enemy)],
    world.transform.posY[world.transform.indexOf(enemy)],
    world.enemy.facing[world.enemy.indexOf(enemy)],
  );

  void step(int tick) {
    cooldown.step(world);
    invulnerability.step(world);
    phase.step(world, currentTick: tick);
    regen.step(world);
    authority.prepareTick(world, player: player, currentTick: tick);
    modes.step(world);
    locomotion.step(
      world,
      player: player,
      groundTopY: 500,
      dtSeconds: 1 / hz,
      currentTick: tick,
    );
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: tick,
    );
    cast.step(world, player: player, currentTick: tick);
    melee.step(world, player: player, currentTick: tick);
    strikes.step(world, currentTick: tick);
    anim.step(
      world,
      player: player,
      currentTick: tick,
      playerSpawnStartTick: -1000,
    );
    hurtboxes.step(world);
    grid.rebuild(world);
    follow.step(world, currentTick: tick);
    hits.step(world, grid, currentTick: tick);
    meleeHits += world.damageQueue.sourceMeleeAbilityId
        .where((id) => id == 'unoco.strike')
        .length;
    damage.step(world, currentTick: tick);
    lifetime.step(world);
    final ti = world.transform.indexOf(enemy);
    final ai = world.activeAbility.indexOf(enemy);
    if (world.activeAbility.abilityId[ai] != null) {
      trace.add(
        'tick=$tick pos=(${world.transform.posX[ti]},${world.transform.posY[ti]}) '
        'vel=(${world.transform.velX[ti]},${world.transform.velY[ti]}) '
        'phase=${world.activeAbility.phase[ai]} hp=$hp',
      );
    }
  }
}

final TerrainGeometry _flatTerrain = const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/unoco-melee-floor',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'floor',
    ),
    vertices: [(0, 500), (1000, 500), (1000, 700), (0, 700)],
  ),
], geometryVersion: 1);
