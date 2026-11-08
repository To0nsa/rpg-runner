import 'package:test/test.dart';
import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  for (final hz in [30, 60, 120]) {
    test('Twin Cut replays only its two blade swings at $hz Hz', () {
      final direct = _core(
        ProjectileId.hunterPistol,
        meleeAbility: 'bounty_hunter.twin_cut',
        tickHz: hz,
      );
      final replayed = _core(
        ProjectileId.hunterPistol,
        meleeAbility: 'bounty_hunter.twin_cut',
        tickHz: hz,
      );
      final frames = <ReplayCommandFrameV1>[];
      final poses = <int>{};
      var hitWindows = 0;
      var wasActive = false;
      for (var tick = 1; tick <= hz * 2; tick++) {
        final strike = tick == hz;
        frames.add(
          ReplayCommandFrameV1.fromJson(
            ReplayCommandFrameV1(
              tick: tick,
              moveAxis: 0,
              pressedMask: strike ? ReplayCommandFrameV1.pressedStrikeBit : 0,
            ).toJson(),
          ),
        );
        direct.applyCommands([if (strike) StrikePressedCommand(tick: tick)]);
        direct.stepOneTick();
        final snapshot = direct.buildSnapshot();
        final player = snapshot.playerEntity!;
        if (player.anim == AnimKey.twinStrike) {
          final step = (.06 * hz).round();
          poses.add(player.animFrame! ~/ step);
        }
        final active = snapshot.entities.any(
          (e) => e.kind == EntityKind.trigger && e.combatCapsules.isNotEmpty,
        );
        if (active && !wasActive) hitWindows++;
        wasActive = active;
        expect(
          snapshot.entities.where((e) => e.kind == EntityKind.projectile),
          isEmpty,
        );
        direct.drainEvents();
      }
      final result = runReplaySimulation(
        core: replayed,
        totalTicks: hz * 2,
        commandStream: frames,
      );
      expect(result.ticksExecuted, hz * 2);
      expect(poses, {0, 1, 2, 3, 4, 5, 6, 7});
      expect(hitWindows, 2);
      expect(_signature(replayed), _signature(direct));
    });
  }
  for (final gun in hunterRangedWeaponIds) {
    test('$gun retains rear firing while moving through replay encoding', () {
      final direct = _core(gun, shotAbility: 'bounty_hunter.quick_shot');
      final replayed = _core(gun, shotAbility: 'bounty_hunter.quick_shot');
      final frames = <ReplayCommandFrameV1>[];
      var sawShot = false;
      final initialX = direct.buildSnapshot().playerEntity!.pos.x;
      for (var tick = 1; tick <= 60; tick++) {
        frames.add(
          ReplayCommandFrameV1.fromJson(
            ReplayCommandFrameV1(
              tick: tick,
              moveAxis: 1,
              aimDirX: -1,
              aimDirY: 0,
              pressedMask: tick == 30
                  ? ReplayCommandFrameV1.pressedProjectileBit
                  : 0,
            ).toJson(),
          ),
        );
        direct.applyCommands([
          MoveAxisCommand(tick: tick, axis: 1),
          AimDirCommand(tick: tick, x: -1, y: 0),
          if (tick == 30) ProjectilePressedCommand(tick: tick),
        ]);
        direct.stepOneTick();
        final snapshot = direct.buildSnapshot();
        final shots = snapshot.entities.where((e) => e.projectileId == gun);
        if (!sawShot && shots.isNotEmpty) {
          final player = snapshot.playerEntity!;
          expect(player.facing, Facing.left);
          expect(player.vel!.x, greaterThan(0));
          expect(player.anim, AnimKey.rangedRun);
          final muzzle = direct.playerCharacter.projectileMuzzles[gun]!.offset(
            renderAnim: direct.playerCharacter.renderAnim,
            grounded: true,
            velocityX: player.vel!.x,
            minMoveSpeed: direct.playerCharacter.tuning.movement.minMoveSpeed,
            currentTick: tick,
            tickHz: 60,
          );
          for (final shot in shots) {
            expect(shot.pos.x, closeTo(player.pos.x - muzzle.x, 1e-9));
            expect(shot.pos.y, closeTo(player.pos.y + muzzle.y, 1e-9));
            expect(shot.facing, Facing.left);
          }
          sawShot = true;
        }
        direct.drainEvents();
      }
      final result = runReplaySimulation(
        core: replayed,
        totalTicks: 60,
        commandStream: frames,
      );
      expect(result.ticksExecuted, 60);
      expect(sawShot, isTrue);
      expect(direct.buildSnapshot().playerEntity!.pos.x, greaterThan(initialX));
      expect(direct.buildSnapshot().playerEntity!.facing, Facing.right);
      expect(_signature(replayed), _signature(direct));
    });
    test(
      '$gun reproduces bombs, shots, melee and movement through replay encoding',
      () {
        final direct = _core(gun), replayed = _core(gun);
        final frames = <ReplayCommandFrameV1>[];
        var sawBomb = false, sawShot = false, sawBlink = false;
        final checkpoints = <int, List<Object?>>{};
        for (var tick = 1; tick <= 600; tick++) {
          if (tick == 1 || tick % 256 == 0)
            checkpoints[tick] = _signature(direct);
          final phase = tick % 240;
          final mask = switch (phase) {
            10 => ReplayCommandFrameV1.pressedDashBit,
            40 => ReplayCommandFrameV1.pressedSecondaryBit,
            100 => ReplayCommandFrameV1.pressedProjectileBit,
            140 => ReplayCommandFrameV1.pressedStrikeBit,
            200 => ReplayCommandFrameV1.pressedJumpBit,
            210 => ReplayCommandFrameV1.pressedJumpBit,
            _ => 0,
          };
          frames.add(
            ReplayCommandFrameV1.fromJson(
              ReplayCommandFrameV1(
                tick: tick,
                moveAxis: 0,
                pressedMask: mask,
              ).toJson(),
            ),
          );
          direct.applyCommands([
            MoveAxisCommand(tick: tick, axis: 0),
            if (phase == 10) DashPressedCommand(tick: tick),
            if (phase == 40) SecondaryPressedCommand(tick: tick),
            if (phase == 100) ProjectilePressedCommand(tick: tick),
            if (phase == 140) StrikePressedCommand(tick: tick),
            if (phase == 200 || phase == 210) JumpPressedCommand(tick: tick),
          ]);
          direct.stepOneTick();
          final snapshot = direct.buildSnapshot();
          sawBlink |= snapshot.playerEntity!.anim == AnimKey.teleportOut;
          sawBomb |= snapshot.entities.any(
            (e) => e.projectileId == ProjectileId.hunterBomb,
          );
          final shots = snapshot.entities.where((e) => e.projectileId == gun);
          if (!sawShot && shots.isNotEmpty) {
            final player = snapshot.playerEntity!;
            expect(player.anim, AnimKey.ranged);
            final muzzle =
                direct.playerCharacter.projectileMuzzles[gun]!.standing;
            final sign = player.facing == Facing.left ? -1 : 1;
            for (final shot in shots) {
              expect(shot.pos.x, closeTo(player.pos.x + muzzle.x * sign, 1e-9));
              expect(shot.pos.y, closeTo(player.pos.y + muzzle.y, 1e-9));
            }
          }
          sawShot |= shots.isNotEmpty;
          direct.drainEvents();
        }
        final result = runReplaySimulation(
          core: replayed,
          totalTicks: 600,
          commandStream: frames,
          onCheckpoint: (tick) =>
              expect(_signature(replayed), checkpoints[tick]),
        );
        expect(result.ticksExecuted, 600);
        expect(sawBlink, isTrue);
        expect(sawBomb, isTrue);
        expect(sawShot, isTrue);
        expect(_signature(replayed), _signature(direct));
        expect(
          replayed.playerCharacter.renderAnim.sourcesByKey.values.join(),
          contains(switch (gun) {
            ProjectileId.hunterCrossbow ||
            ProjectileId.hunterLongwatchCrossbow ||
            ProjectileId.hunterHeavyLimbCrossbow => '/crossbow/',
            ProjectileId.hunterShotgun ||
            ProjectileId.hunterBrushgun => '/shotgun/',
            _ => '/gun/',
          }),
        );
      },
    );
  }
}

GameCore _core(
  ProjectileId gun, {
  String shotAbility = 'bounty_hunter.snap_shot',
  String meleeAbility = 'bounty_hunter.lunge_slash',
  int tickHz = 60,
}) => GameCore(
  seed: 98,
  tickHz: tickHz,
  playerCharacter: PlayerCharacterRegistry.bountyHunter,
  equippedLoadoutOverride: EquippedLoadoutDef(
    mask: LoadoutSlotMask.all,
    mainWeaponId: WeaponId.hunterNotchknife,
    offhandWeaponId: WeaponId.hunterSnareRig,
    spellBookId: SpellBookId.hunterLongtrailPack,
    projectileSlotSpellId: gun,
    abilityPrimaryId: meleeAbility,
    abilitySecondaryId: 'bounty_hunter.blast_bomb',
    abilityProjectileId: shotAbility,
    abilitySpellId: 'bounty_hunter.prepare_charges',
    abilityMobilityId: 'bounty_hunter.blink_dash',
    abilityJumpId: 'bounty_hunter.double_jump',
  ),
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    tuning: const CoreTuning(
      camera: CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
      track: TrackTuning(enabled: false),
    ),
  ),
);

List<Object?> _signature(GameCore core) {
  final s = core.buildSnapshot();
  return [
    core.tick,
    core.gameOver,
    s.hud.hp,
    s.hud.mana,
    s.hud.stamina,
    s.hud.cooldownTicksLeft,
    for (final e in s.entities)
      (
        e.id,
        e.projectileId,
        e.pos.x,
        e.pos.y,
        e.vel?.x,
        e.vel?.y,
        e.facing,
        e.anim,
        e.animFrame,
        e.statusVisualMask,
      ),
  ];
}
