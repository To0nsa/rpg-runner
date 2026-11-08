import 'package:test/test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/anim/anim_state_store.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  for (final hz in [30, 60, 120]) {
    for (final axis in [0.0, 1.0]) {
      test('frame 4 covers coast then recovery at $hz Hz, axis=$axis', () {
        final visual = _core(hz);
        final reference = _core(hz, hold: false);
        final frames = <int>[];
        final step = (.04 * hz).round();
        var normalSpeed = 0.0;
        var recovered = false;
        for (var i = 0; i < hz * 4; i++) {
          final relative = i - hz * 2;
          final commands = <Command>[
            MoveAxisCommand(tick: visual.tick + 1, axis: i >= hz ? axis : 0),
            if (relative == 0) DashPressedCommand(tick: visual.tick + 1),
          ];
          for (final core in [visual, reference]) {
            core.applyCommands(commands);
            core.stepOneTick();
          }
          final snapshot = visual.buildSnapshot();
          final baseline = reference.buildSnapshot();
          final player = snapshot.entities.singleWhere(_isPlayer);
          final previous = baseline.entities.singleWhere(_isPlayer);
          expect(_physics(player), _physics(previous));
          expect(snapshot.distance, baseline.distance);
          expect(snapshot.hud.hp, baseline.hud.hp);
          expect(snapshot.hud.stamina, baseline.hud.stamina);
          expect(
            snapshot.hud.cooldownTicksLeft,
            baseline.hud.cooldownTicksLeft,
          );
          final ghost = visual.buildActorFrameSnapshot().entities.singleWhere(
            _isPlayer,
          );
          expect(
            (ghost.anim, ghost.animFrame),
            (player.anim, player.animFrame),
          );
          if (relative == -1) normalSpeed = player.vel!.x;
          if (relative < 0) continue;
          if (player.anim == AnimKey.dash) {
            expect(
              recovered,
              isFalse,
              reason: 'Do not restart a completed dash',
            );
            final frame = player.animFrame! ~/ step;
            frames.add(frame);
            if (previous.anim != AnimKey.dash && player.vel!.x > normalSpeed) {
              expect(frame, 3, reason: 'Frame 4 covers all excess movement');
            }
          } else {
            recovered = true;
          }
        }
        expect(recovered, isTrue);
        expect(frames.toSet().toList(), [0, 1, 2, 3, 4, 5, 6]);
        expect(frames.where((f) => f == 3).length, greaterThan(step));
        for (final frame in [0, 1, 2, 4, 5, 6]) {
          expect(frames.where((f) => f == frame).length, step);
        }
      });
    }
  }

  test('air dash returns to falling without grounded recovery', () {
    final core = _core(60);
    for (var i = 0; i < 138; i++) {
      core.applyCommands([
        MoveAxisCommand(tick: core.tick + 1, axis: 1),
        if (i == 114) JumpPressedCommand(tick: core.tick + 1),
        if (i == 120) DashPressedCommand(tick: core.tick + 1),
      ]);
      core.stepOneTick();
      if (i == 131) {
        final player = core.buildSnapshot().entities.singleWhere(_isPlayer);
        expect(player.grounded, isFalse);
        expect((player.anim, player.animFrame), (AnimKey.dash, 6));
      }
      if (i == 132) {
        final player = core.buildSnapshot().entities.singleWhere(_isPlayer);
        expect(player.grounded, isFalse);
        expect(player.anim, isNot(AnimKey.dash));
      }
    }
  });

  for (final interrupt in [
    'jump',
    'strike',
    'reverse',
    'swim',
    'hit',
    'stun',
    'death',
  ]) {
    test('$interrupt cancels the continuation immediately', () {
      final fixture = _Fixture();
      fixture.dash(100);
      fixture.step(112);
      expect(fixture.frame, 6);
      final w = fixture.world;
      final p = fixture.player;
      switch (interrupt) {
        case 'jump':
          w.activeAbility.set(
            p,
            id: 'bounty_hunter.jump',
            slot: AbilitySlot.jump,
            commitTick: 113,
            windupTicks: 0,
            activeTicks: 1,
            recoveryTicks: 0,
            facingDir: Facing.right,
          );
        case 'strike':
          w.activeAbility.set(
            p,
            id: 'bounty_hunter.quick_cut',
            slot: AbilitySlot.primary,
            commitTick: 113,
            windupTicks: 3,
            activeTicks: 5,
            recoveryTicks: 4,
            facingDir: Facing.right,
          );
        case 'reverse':
          w.movement.facing[w.movement.indexOf(p)] = Facing.left;
        case 'swim':
          w.swimState.add(p);
          w.swimState.setImmersion(w.swimState.indexOf(p), 1000);
        case 'hit':
          w.lastDamage.tick[w.lastDamage.indexOf(p)] = 113;
        case 'stun':
          w.controlLock.addLock(p, LockFlag.stun, 10, 113);
        case 'death':
          w.health.hp[w.health.indexOf(p)] = 0;
      }
      fixture.step(113);
      expect(fixture.frame, -1);
      fixture.step(114);
      expect(fixture.frame, -1);
    });
  }

  test('rejected jump input does not interrupt a continuing dash', () {
    final fixture = _Fixture();
    fixture.dash(100);
    fixture.world.playerInput.jumpPressed[fixture.world.playerInput.indexOf(
          fixture.player,
        )] =
        true;
    fixture.step(112);
    expect(fixture.frame, 6);
  });

  test('repeated animation pass does not advance; new dash restarts entry', () {
    final fixture = _Fixture();
    fixture.dash(100);
    fixture.step(112);
    fixture.world.transform.velX[fixture.world.transform.indexOf(
          fixture.player,
        )] =
        0;
    fixture.step(113);
    expect(fixture.frame, 8);
    fixture.step(113);
    expect(fixture.frame, 8);
    fixture.dash(114);
    expect(fixture.frame, 0);
  });

  for (final direction in [-1.0, 1.0]) {
    test('downhill normal speed ends the hold facing $direction', () {
      final fixture = _Fixture();
      final w = fixture.world;
      final p = fixture.player;
      final mi = w.movement.indexOf(p);
      w.movement.dashDirX[mi] = direction;
      w.movement.facing[mi] = direction > 0 ? Facing.right : Facing.left;
      w.transform.velX[w.transform.indexOf(p)] = direction * 500;
      w.terrainContact.add(p);
      final ci = w.terrainContact.indexOf(p);
      w.terrainContact.grounded[ci] = true;
      w.terrainContact.supportEdgeId[ci] = TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'slope',
        shapeId: 'ground',
        localEdgeIndex: 0,
      );
      w.terrainContact.supportTangentXTicks[ci] = 887;
      w.terrainContact.supportTangentYTicks[ci] = (direction * 512).toInt();
      w.terrainContact.supportSlopeAngleUnits[ci] =
          30 * terrainSlopeAngleUnitsPerDegree;
      w.terrainTraversalProfile.add(
        p,
        createEloiseTerrainTraversalProfile(
          enabled: true,
          isKinematic: false,
          useGravity: true,
          gravityScale: 1,
          collideCeilings: true,
          collideLeftWalls: true,
          collideRightWalls: true,
        ),
      );
      w.resolvedMotion.add(p);
      w.resolvedMotion.setLocomotionReferenceSpeed(
        p,
        ticksPerSecond: 200 * terrainPhysicsTicksPerWorldUnit,
      );
      fixture.dash(100);
      fixture.step(112);
      expect(fixture.frame, 6);
      // The profile's normal 30-degree downhill target is 105% of flat speed.
      w.transform.velX[w.transform.indexOf(p)] = direction * 210;
      fixture.step(113);
      expect(fixture.frame, 8);
      fixture.step(119);
      expect(fixture.frame, -1);
    });
  }

  test('dash presentation follows swap removal and resets on entity reuse', () {
    final store = AnimStateStore()
      ..add(1)
      ..add(2);
    store.dashVisualStartTick[1] = 100;
    store.dashVisualRecoveryStartTick[1] = 140;
    store.dashVisualFrame[1] = 10;
    store.removeEntity(1);
    expect(store.dashVisualStartTick, [100]);
    expect(store.dashVisualRecoveryStartTick, [140]);
    expect(store.dashVisualFrame, [10]);
    store.removeEntity(2);
    store.add(2);
    expect(store.dashVisualStartTick, [-1]);
    expect(store.dashVisualRecoveryStartTick, [-1]);
    expect(store.dashVisualFrame, [-1]);
  });
}

bool _isPlayer(EntityRenderSnapshot e) => e.kind == EntityKind.player;

Object _physics(EntityRenderSnapshot e) => [
  e.pos.x,
  e.pos.y,
  e.vel?.x,
  e.vel?.y,
  e.grounded,
  e.facing,
  for (final c in e.combatCapsules) [c.ax, c.ay, c.bx, c.by, c.radius],
];

GameCore _core(int hz, {bool hold = true}) {
  final original = bountyHunterCharacter;
  final r = original.renderAnim;
  final character = hold
      ? original
      : PlayerCharacterDefinition(
          id: original.id,
          displayName: original.displayName,
          catalog: original.catalog,
          tuning: original.tuning,
          renderScale: original.renderScale,
          projectileMuzzles: original.projectileMuzzles,
          renderAnim: RenderAnimSetDefinition(
            frameWidth: r.frameWidth,
            frameHeight: r.frameHeight,
            anchorPoint: r.anchorPoint,
            sourcesByKey: r.sourcesByKey,
            rowByKey: r.rowByKey,
            frameStartByKey: r.frameStartByKey,
            gridColumnsByKey: r.gridColumnsByKey,
            sourceFramesByKey: r.sourceFramesByKey,
            anchorPointByKey: r.anchorPointByKey,
            compositeFramesByKey: r.compositeFramesByKey,
            frameCountsByKey: r.frameCountsByKey,
            stepTimeSecondsByKey: r.stepTimeSecondsByKey,
          ),
        );
  return GameCore(
    seed: 1,
    tickHz: hz,
    playerCharacter: character,
    levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
      tuning: const CoreTuning(
        camera: CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
        track: TrackTuning(enabled: false),
      ),
    ),
  );
}

class _Fixture {
  final world = EcsWorld();
  late final player = EntityFactory(world).createPlayer(
    posX: 0,
    posY: 0,
    velX: 500,
    velY: 0,
    facing: Facing.right,
    grounded: true,
    body: const BodyDef(isKinematic: true, useGravity: false),
    collider: const ColliderAabbDef(halfX: 8, halfY: 8),
    health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
    stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
  );
  final system = AnimSystem(
    tickHz: 60,
    enemyCatalog: const EnemyCatalog(),
    playerRenderAnim: bountyHunterCharacter.renderAnim,
    playerMovement: MovementTuningDerived.from(
      bountyHunterCharacter.tuning.movement,
      tickHz: 60,
    ),
    playerAnimTuning: AnimTuningDerived.from(
      bountyHunterCharacter.tuning.anim,
      tickHz: 60,
    ),
  );
  int get frame =>
      world.animState.dashVisualFrame[world.animState.indexOf(player)];
  void step(int tick) {
    ActiveAbilityPhaseSystem().step(world, currentTick: tick);
    system.step(
      world,
      player: player,
      currentTick: tick,
      playerSpawnStartTick: -1,
    );
  }

  void dash(int tick) {
    world.activeAbility.set(
      player,
      id: 'bounty_hunter.dash',
      slot: AbilitySlot.mobility,
      commitTick: tick,
      windupTicks: 0,
      activeTicks: 12,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );
    step(tick);
  }
}
