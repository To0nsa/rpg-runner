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
import 'ecs/systems/movement_system.dart';
import 'ecs/systems/resource_regen_system.dart';
import 'ecs/stores/body_store.dart';
import 'ecs/stores/health_store.dart';
import 'ecs/stores/mana_store.dart';
import 'ecs/stores/stamina_store.dart';
import 'ecs/world.dart';
import 'math/vec2.dart';
import 'snapshots/enums.dart';
import 'snapshots/entity_render_snapshot.dart';
import 'snapshots/game_state_snapshot.dart';
import 'snapshots/player_hud_snapshot.dart';
import 'snapshots/static_solid_snapshot.dart';
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
    BodyDef? playerBody,
    StaticWorldGeometry? staticWorldGeometry,
  }) : _movement = V0MovementTuningDerived.from(
         movementTuning,
         tickHz: tickHz,
       ),
       _resourceTuning = resourceTuning,
       staticWorldGeometry = staticWorldGeometry ?? v0DefaultStaticWorldGeometry {
    _world = EcsWorld();
    _movementSystem = MovementSystem();
    _collisionSystem = CollisionSystem();
    _resourceRegenSystem = ResourceRegenSystem();

    final spawnPos = Vec2(
      80,
      (this.staticWorldGeometry.groundPlane?.topY ?? v0GroundTopY.toDouble()) -
          _movement.base.playerRadius,
    );
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
      pos: spawnPos,
      vel: const Vec2(0, 0),
      facing: Facing.right,
      grounded: true,
      body: playerBody ?? defaultBody,
      collider: ColliderAabbDef(
        halfExtents: Vec2(
          _movement.base.playerRadius,
          _movement.base.playerRadius,
        ),
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

  late final EcsWorld _world;
  late final MovementSystem _movementSystem;
  late final CollisionSystem _collisionSystem;
  late final ResourceRegenSystem _resourceRegenSystem;
  late final EntityId _player;

  /// Current simulation tick.
  int tick = 0;

  /// Whether simulation should advance.
  bool paused = false;

  /// Run progression metric (placeholder).
  double distance = 0;

  Vec2 get playerPos => _world.transform.getPos(_player);
  set playerPos(Vec2 value) => _world.transform.setPos(_player, value);

  Vec2 get playerVel => _world.transform.getVel(_player);
  set playerVel(Vec2 value) => _world.transform.setVel(_player, value);

  bool get playerGrounded =>
      _world.collision.grounded[_world.collision.indexOf(_player)];

  Facing get playerFacing =>
      _world.movement.facing[_world.movement.indexOf(_player)];
  set playerFacing(Facing value) {
    _world.movement.facing[_world.movement.indexOf(_player)] = value;
  }

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
        case CastPressedCommand():
          _world.playerInput.castPressed[inputIndex] = true;
      }
    }
  }

  /// Advances the simulation by exactly one fixed tick.
  void stepOneTick() {
    if (paused) return;

    tick += 1;
    _movementSystem.step(_world, _movement, resources: _resourceTuning);
    _collisionSystem.step(
      _world,
      _movement,
      staticWorld: _staticWorldIndex,
    );
    _resourceRegenSystem.step(_world, dtSeconds: _movement.dtSeconds);

    distance += max(0.0, playerVel.x) * _movement.dtSeconds;
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
      anim = playerVel.y < 0 ? AnimKey.jump : AnimKey.fall;
    } else if (playerVel.x.abs() > tuning.minMoveSpeed) {
      anim = AnimKey.run;
    } else {
      anim = AnimKey.idle;
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
      entities: [
        EntityRenderSnapshot(
          id: _player,
          kind: EntityKind.player,
          pos: playerPos,
          vel: playerVel,
          facing: playerFacing,
          anim: anim,
          grounded: onGround,
        ),
      ],
      staticSolids: _staticSolidsSnapshot,
    );
  }
}
