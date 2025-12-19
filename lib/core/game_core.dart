// Authoritative, deterministic simulation layer (pure Dart).
//
// This is the "truth" of the game: it applies tick-stamped commands, advances
// the simulation by fixed ticks, and produces snapshots/events for the
// renderer/UI. It must not import Flutter or Flame.
import 'dart:math';

import 'commands/command.dart';
import 'collision/static_world_geometry.dart';
import 'collision/static_world_geometry_index.dart';
import 'contracts/v0_render_contract.dart';
import 'ecs/entity_id.dart';
import 'ecs/stores/collider_aabb_store.dart';
import 'ecs/systems/collision_system.dart';
import 'ecs/systems/cooldown_system.dart';
import 'ecs/systems/cast_system.dart';
import 'ecs/systems/damage_system.dart';
import 'ecs/systems/death_system.dart';
import 'ecs/systems/enemy_system.dart';
import 'ecs/systems/hitbox_damage_system.dart';
import 'ecs/systems/invulnerability_system.dart';
import 'ecs/systems/lifetime_system.dart';
import 'ecs/systems/melee_system.dart';
import 'ecs/systems/movement_system.dart';
import 'ecs/systems/projectile_system.dart';
import 'ecs/systems/projectile_hit_system.dart';
import 'ecs/systems/resource_regen_system.dart';
import 'ecs/stores/body_store.dart';
import 'ecs/stores/health_store.dart';
import 'ecs/stores/mana_store.dart';
import 'ecs/stores/stamina_store.dart';
import 'ecs/world.dart';
import 'enemies/enemy_id.dart';
import 'math/vec2.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
import 'projectiles/projectile_catalog.dart';
import 'spells/spell_catalog.dart';
import 'tuning/v0_ability_tuning.dart';
import 'tuning/v0_combat_tuning.dart';
import 'tuning/v0_enemy_tuning.dart';
import 'tuning/v0_movement_tuning.dart';
import 'tuning/v0_resource_tuning.dart';

const StaticWorldGeometry v0DefaultStaticWorldGeometry = StaticWorldGeometry(
  groundPlane: StaticGroundPlane(topY: v0GroundTopY * 1.0),
  solids: <StaticSolid>[
    // A small one-way platform to validate collisions/visuals.
    StaticSolid(
      minX: 120,
      minY: 200,
      maxX: 280,
      maxY: 216,
      sides: StaticSolid.sideTop,
      oneWayTop: true,
    ),

    // A simple obstacle block to validate side collisions + jumping.
    StaticSolid(
      minX: 320,
      minY: 220,
      maxX: 344,
      maxY: v0GroundTopY * 1.0,
      sides: StaticSolid.sideAll,
      oneWayTop: false,
    ),
  ],
);

/// Minimal placeholder `GameCore` used to validate architecture wiring.
///
/// This will be replaced by the full ECS/systems implementation in later
/// milestones. The core invariants remain: fixed ticks, command-driven input,
/// deterministic state updates, snapshot output.
class GameCore {
  GameCore({
    required this.seed,
    this.tickHz = v0DefaultTickHz,
    V0MovementTuning movementTuning = const V0MovementTuning(),
    V0ResourceTuning resourceTuning = const V0ResourceTuning(),
    V0AbilityTuning abilityTuning = const V0AbilityTuning(),
    V0CombatTuning combatTuning = const V0CombatTuning(),
    V0EnemyTuning enemyTuning = const V0EnemyTuning(),
    SpellCatalog spellCatalog = const SpellCatalog(),
    ProjectileCatalog projectileCatalog = const ProjectileCatalog(),
    BodyDef? playerBody,
    StaticWorldGeometry? staticWorldGeometry,
  }) : _movement = V0MovementTuningDerived.from(
         movementTuning,
         tickHz: tickHz,
       ),
       _resourceTuning = resourceTuning,
       _abilities = V0AbilityTuningDerived.from(abilityTuning, tickHz: tickHz),
       _combat = V0CombatTuningDerived.from(combatTuning, tickHz: tickHz),
       _enemyTuning = V0EnemyTuningDerived.from(enemyTuning, tickHz: tickHz),
       _spells = spellCatalog,
       _projectiles = ProjectileCatalogDerived.from(
         projectileCatalog,
         tickHz: tickHz,
       ),
       staticWorldGeometry = staticWorldGeometry ?? v0DefaultStaticWorldGeometry {
    _world = EcsWorld();
    _movementSystem = MovementSystem();
    _collisionSystem = CollisionSystem();
    _cooldownSystem = CooldownSystem();
    _projectileSystem = ProjectileSystem();
    _projectileHitSystem = ProjectileHitSystem();
    _lifetimeSystem = LifetimeSystem();
    _invulnerabilitySystem = InvulnerabilitySystem();
    _damageSystem = DamageSystem(invulnerabilityTicksOnHit: _combat.invulnerabilityTicks);
    _deathSystem = DeathSystem();
    _meleeSystem = MeleeSystem(abilities: _abilities, movement: _movement);
    _hitboxDamageSystem = HitboxDamageSystem();
    _resourceRegenSystem = ResourceRegenSystem();
    _castSystem = CastSystem(
      spells: _spells,
      projectiles: _projectiles,
      abilities: _abilities,
      movement: _movement,
    );
    _enemySystem = EnemySystem(
      tuning: _enemyTuning,
      spells: _spells,
      projectiles: _projectiles,
    );

    final spawnX = 80.0;
    final spawnY =
        (this.staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble()) -
        _movement.base.playerRadius;
    final defaultBody = BodyDef(
      enabled: true,
      isKinematic: false,
      useGravity: true,
      topOnlyGround: true,
      gravityScale: 1.0,
      maxVelX: _movement.base.maxVelX,
      maxVelY: _movement.base.maxVelY,
      sideMask: BodyDef.sideLeft | BodyDef.sideRight,
    );
    _player = _world.createPlayer(
      posX: spawnX,
      posY: spawnY,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.right,
      grounded: true,
      body: playerBody ?? defaultBody,
      collider: ColliderAabbDef(
        halfX: _movement.base.playerRadius,
        halfY: _movement.base.playerRadius,
      ),
      health: HealthDef(
        hp: _resourceTuning.playerHpStart ?? _resourceTuning.playerHpMax,
        hpMax: _resourceTuning.playerHpMax,
        regenPerSecond: _resourceTuning.playerHpRegenPerSecond,
      ),
      mana: ManaDef(
        mana: _resourceTuning.playerManaStart ?? _resourceTuning.playerManaMax,
        manaMax: _resourceTuning.playerManaMax,
        regenPerSecond: _resourceTuning.playerManaRegenPerSecond,
      ),
      stamina: StaminaDef(
        stamina:
            _resourceTuning.playerStaminaStart ?? _resourceTuning.playerStaminaMax,
        staminaMax: _resourceTuning.playerStaminaMax,
        regenPerSecond: _resourceTuning.playerStaminaRegenPerSecond,
      ),
    );

    // Deterministic enemy spawns for Milestone 7 (no RNG yet).
    //
    // These are intentionally hardcoded so combat systems can be tested and
    // debugged without introducing spawning determinism and world-gen at once.
    final groundTopY =
        this.staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble();

    final demon = _world.createEnemy(
      enemyId: EnemyId.demon,
      posX: spawnX + 220.0,
      posY: groundTopY - 90.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: const BodyDef(
        isKinematic: false,
        useGravity: false,
        gravityScale: 0.0,
        sideMask: BodyDef.sideNone,
        maxVelX: 800.0,
        maxVelY: 800.0,
      ),
      collider: const ColliderAabbDef(halfX: 12.0, halfY: 12.0),
      health: const HealthDef(hp: 50.0, hpMax: 50.0, regenPerSecond: 0.0),
      mana: const ManaDef(mana: 80.0, manaMax: 80.0, regenPerSecond: 5.0),
      stamina: const StaminaDef(stamina: 0.0, staminaMax: 0.0, regenPerSecond: 0.0),
    );
    // Avoid immediate spawn-tick casting (keeps early-game tests stable).
    _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(demon)] =
        _enemyTuning.demonCastCooldownTicks;

    _world.createEnemy(
      enemyId: EnemyId.fireWorm,
      posX: spawnX + 300.0,
      posY: groundTopY - 12.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelX: _movement.base.maxVelX,
        maxVelY: _movement.base.maxVelY,
        sideMask: BodyDef.sideLeft | BodyDef.sideRight,
      ),
      collider: const ColliderAabbDef(halfX: 12.0, halfY: 12.0),
      health: const HealthDef(hp: 50.0, hpMax: 50.0, regenPerSecond: 0.0),
      mana: const ManaDef(mana: 0.0, manaMax: 0.0, regenPerSecond: 0.0),
      stamina: const StaminaDef(stamina: 0.0, staminaMax: 0.0, regenPerSecond: 0.0),
    );
  }

  /// Seed used for deterministic generation/RNG.
  final int seed;

  /// Fixed simulation tick frequency.
  final int tickHz;

  /// Static world geometry for this run/session.
  final StaticWorldGeometry staticWorldGeometry;
  late final StaticWorldGeometryIndex _staticWorldIndex =
      StaticWorldGeometryIndex.from(staticWorldGeometry);

  late final List<StaticSolidSnapshot> _staticSolidsSnapshot =
      List<StaticSolidSnapshot>.unmodifiable(
        staticWorldGeometry.solids.map(
          (s) => StaticSolidSnapshot(
            minX: s.minX,
            minY: s.minY,
            maxX: s.maxX,
            maxY: s.maxY,
            sides: s.sides,
            oneWayTop: s.oneWayTop,
          ),
        ),
      );

  final V0MovementTuningDerived _movement;
  final V0ResourceTuning _resourceTuning;
  final V0AbilityTuningDerived _abilities;
  final V0CombatTuningDerived _combat;
  final V0EnemyTuningDerived _enemyTuning;
  final SpellCatalog _spells;
  final ProjectileCatalogDerived _projectiles;

  late final EcsWorld _world;
  late final MovementSystem _movementSystem;
  late final CollisionSystem _collisionSystem;
  late final CooldownSystem _cooldownSystem;
  late final ProjectileSystem _projectileSystem;
  late final ProjectileHitSystem _projectileHitSystem;
  late final LifetimeSystem _lifetimeSystem;
  late final InvulnerabilitySystem _invulnerabilitySystem;
  late final DamageSystem _damageSystem;
  late final DeathSystem _deathSystem;
  late final EnemySystem _enemySystem;
  late final MeleeSystem _meleeSystem;
  late final HitboxDamageSystem _hitboxDamageSystem;
  late final ResourceRegenSystem _resourceRegenSystem;
  late final CastSystem _castSystem;
  late final EntityId _player;

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Run progression metric (placeholder).
  double distance = 0;

  double get playerPosX =>
      _world.transform.posX[_world.transform.indexOf(_player)];
  double get playerPosY =>
      _world.transform.posY[_world.transform.indexOf(_player)];

  void setPlayerPosXY(double x, double y) =>
      _world.transform.setPosXY(_player, x, y);

  double get playerVelX =>
      _world.transform.velX[_world.transform.indexOf(_player)];
  double get playerVelY =>
      _world.transform.velY[_world.transform.indexOf(_player)];

  void setPlayerVelXY(double x, double y) =>
      _world.transform.setVelXY(_player, x, y);

  bool get playerGrounded =>
      _world.collision.grounded[_world.collision.indexOf(_player)];

  Facing get playerFacing =>
      _world.movement.facing[_world.movement.indexOf(_player)];
  set playerFacing(Facing value) {
    _world.movement.facing[_world.movement.indexOf(_player)] = value;
  }

  int get playerCastCooldownTicksLeft =>
      _world.cooldown.castCooldownTicksLeft[_world.cooldown.indexOf(_player)];

  int get playerMeleeCooldownTicksLeft =>
      _world.cooldown.meleeCooldownTicksLeft[_world.cooldown.indexOf(_player)];

  /// Applies all commands scheduled for the current tick.
  ///
  /// In the final architecture, commands are the only mechanism for the UI to
  /// influence the simulation.
  void applyCommands(List<Command> commands) {
    _world.playerInput.resetTickInputs(_player);
    final inputIndex = _world.playerInput.indexOf(_player);
    final movementIndex = _world.movement.indexOf(_player);

    for (final command in commands) {
      switch (command) {
        case MoveAxisCommand(:final axis):
          final clamped = axis.clamp(-1.0, 1.0);
          _world.playerInput.moveAxis[inputIndex] = clamped;

          if (_world.movement.dashTicksLeft[movementIndex] == 0) {
            if (clamped < 0) {
              playerFacing = Facing.left;
            } else if (clamped > 0) {
              playerFacing = Facing.right;
            }
          }
        case JumpPressedCommand():
          _world.playerInput.jumpPressed[inputIndex] = true;
        case DashPressedCommand():
          _world.playerInput.dashPressed[inputIndex] = true;
        case AttackPressedCommand():
          _world.playerInput.attackPressed[inputIndex] = true;
          break;
        case AimDirCommand(:final x, :final y):
          _world.playerInput.aimDirX[inputIndex] = x;
          _world.playerInput.aimDirY[inputIndex] = y;
        case ClearAimDirCommand():
          _world.playerInput.aimDirX[inputIndex] = 0;
          _world.playerInput.aimDirY[inputIndex] = 0;
        case CastPressedCommand():
          _world.playerInput.castPressed[inputIndex] = true;
      }
    }
  }

  /// Advances the simulation by exactly one fixed tick.
  void stepOneTick() {
    if (paused) return;

    tick += 1;
    _cooldownSystem.step(_world);
    _invulnerabilitySystem.step(_world);

    final groundTopY =
        staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble();
    _enemySystem.stepSteering(_world, player: _player, groundTopY: groundTopY);

    _movementSystem.step(_world, _movement, resources: _resourceTuning);
    _collisionSystem.step(
      _world,
      _movement,
      staticWorld: _staticWorldIndex,
    );
    _projectileSystem.step(_world, _movement);
    _projectileHitSystem.step(_world, _damageSystem.queue);
    _enemySystem.stepAttacks(_world, player: _player);
    _castSystem.step(_world, player: _player);
    _meleeSystem.step(_world, player: _player);
    _hitboxDamageSystem.step(_world, _damageSystem.queue);
    _damageSystem.step(_world);
    _deathSystem.step(_world, player: _player);
    _resourceRegenSystem.step(_world, dtSeconds: _movement.dtSeconds);

    // Cleanup last so effect entities get their full last tick to act.
    _lifetimeSystem.step(_world);

    distance += max(0.0, playerVelX) * _movement.dtSeconds;
  }

  /// Builds an immutable snapshot for render/UI consumption.
  GameStateSnapshot buildSnapshot() {
    final tuning = _movement.base;
    final mi = _world.movement.indexOf(_player);
    final dashing = _world.movement.dashTicksLeft[mi] > 0;
    final onGround = _world.collision.grounded[_world.collision.indexOf(_player)];
    final hi = _world.health.indexOf(_player);
    final mai = _world.mana.indexOf(_player);
    final si = _world.stamina.indexOf(_player);

    final AnimKey anim;
    if (dashing) {
      anim = AnimKey.run;
    } else if (!onGround) {
      anim = playerVelY < 0 ? AnimKey.jump : AnimKey.fall;
    } else if (playerVelX.abs() > tuning.minMoveSpeed) {
      anim = AnimKey.run;
    } else {
      anim = AnimKey.idle;
    }

    final playerPos = Vec2(playerPosX, playerPosY);
    final playerVel = Vec2(playerVelX, playerVelY);

    final entities = <EntityRenderSnapshot>[
      EntityRenderSnapshot(
        id: _player,
        kind: EntityKind.player,
        pos: playerPos,
        vel: playerVel,
        size: Vec2(tuning.playerRadius * 2, tuning.playerRadius * 2),
        facing: playerFacing,
        anim: anim,
        grounded: onGround,
      ),
    ];

    final projectileStore = _world.projectile;
    for (var pi = 0; pi < projectileStore.denseEntities.length; pi += 1) {
      final e = projectileStore.denseEntities[pi];
      if (!(_world.transform.has(e))) continue;
      final ti = _world.transform.indexOf(e);

      final projectileId = projectileStore.projectileId[pi];
      final proj = _projectiles.base.get(projectileId);
      final colliderSize = Vec2(proj.colliderSizeX, proj.colliderSizeY);

      final dx = projectileStore.dirX[pi];
      final facing = dx >= 0 ? Facing.right : Facing.left;

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.projectile,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          vel: Vec2(_world.transform.velX[ti], _world.transform.velY[ti]),
          size: colliderSize,
          projectileId: projectileId,
          facing: facing,
          anim: AnimKey.idle,
          grounded: false,
        ),
      );
    }

    final hitboxes = _world.hitbox;
    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final e = hitboxes.denseEntities[hi];
      if (!(_world.transform.has(e))) continue;
      final ti = _world.transform.indexOf(e);

      final size = Vec2(hitboxes.halfX[hi] * 2, hitboxes.halfY[hi] * 2);
      final facing = hitboxes.offsetX[hi] >= 0 ? Facing.right : Facing.left;

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.trigger,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          size: size,
          facing: facing,
          anim: AnimKey.hit,
          grounded: false,
        ),
      );
    }

    final enemies = _world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final e = enemies.denseEntities[ei];
      if (!(_world.transform.has(e))) continue;
      final ti = _world.transform.indexOf(e);

      Vec2? size;
      if (_world.colliderAabb.has(e)) {
        final aabbi = _world.colliderAabb.indexOf(e);
        size = Vec2(
          _world.colliderAabb.halfX[aabbi] * 2,
          _world.colliderAabb.halfY[aabbi] * 2,
        );
      }

      entities.add(
        EntityRenderSnapshot(
          id: e,
          kind: EntityKind.enemy,
          pos: Vec2(_world.transform.posX[ti], _world.transform.posY[ti]),
          vel: Vec2(_world.transform.velX[ti], _world.transform.velY[ti]),
          size: size,
          facing: enemies.facing[ei],
          anim: AnimKey.idle,
          grounded: _world.collision.has(e)
              ? _world.collision.grounded[_world.collision.indexOf(e)]
              : false,
        ),
      );
    }

    return GameStateSnapshot(
      tick: tick,
      seed: seed,
      distance: distance,
      paused: paused,
      hud: PlayerHudSnapshot(
        hp: _world.health.hp[hi],
        hpMax: _world.health.hpMax[hi],
        mana: _world.mana.mana[mai],
        manaMax: _world.mana.manaMax[mai],
        stamina: _world.stamina.stamina[si],
        staminaMax: _world.stamina.staminaMax[si],
        score: 0,
        coins: 0,
      ),
      entities: entities,
      staticSolids: _staticSolidsSnapshot,
    );
  }
}
