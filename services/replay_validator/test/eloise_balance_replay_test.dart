import 'package:test/test.dart';
import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final spell in [
      'arcane_haste',
      'focus',
      'arcane_ward',
      'cleanse',
      'vital_surge',
      'second_wind',
    ]) {
      for (final shot in ['quick_shot', 'overcharge_shot']) {
        test(
          '$spell/$shot round trips charged combat and utility at $hz Hz',
          () {
            final direct = _core(hz, spell, shot),
                replayed = _core(hz, spell, shot);
            final frames = <ReplayCommandFrameV1>[];
            final checkpoints = <int, List<Object?>>{};
            var sawShot = false, sawCharge = false;
            for (var tick = 1; tick <= hz * 12; tick++) {
              if (tick == 1 || tick % 256 == 0) {
                checkpoints[tick] = _signature(direct);
              }
              final phase = tick % (hz * 4);
              final meleeRelease = hz + (20 * hz / 60).ceil();
              final shotRelease = hz * 2 + (24 * hz / 60).ceil();
              AbilitySlot? heldSlot;
              var held = false;
              if (phase == hz || phase == meleeRelease) {
                heldSlot = AbilitySlot.primary;
                held = phase == hz;
              } else if (phase == hz * 2 || phase == shotRelease) {
                heldSlot = AbilitySlot.projectile;
                held = phase == hz * 2;
              }
              final mask = phase == meleeRelease
                  ? ReplayCommandFrameV1.pressedStrikeBit
                  : phase == shotRelease
                  ? ReplayCommandFrameV1.pressedProjectileBit
                  : phase == hz * 3
                  ? ReplayCommandFrameV1.pressedSpellBit
                  : 0;
              final bit = heldSlot == null ? 0 : 1 << heldSlot.index;
              frames.add(
                ReplayCommandFrameV1.fromJson(
                  ReplayCommandFrameV1(
                    tick: tick,
                    moveAxis: 0,
                    aimDirX: 1,
                    aimDirY: 0,
                    pressedMask: mask,
                    abilitySlotHeldChangedMask: bit,
                    abilitySlotHeldValueMask: held ? bit : 0,
                  ).toJson(),
                ),
              );
              direct.applyCommands([
                MoveAxisCommand(tick: tick, axis: 0),
                AimDirCommand(tick: tick, x: 1, y: 0),
                if (heldSlot != null)
                  AbilitySlotHeldCommand(
                    tick: tick,
                    slot: heldSlot,
                    held: held,
                  ),
                if (phase == meleeRelease) StrikePressedCommand(tick: tick),
                if (phase == shotRelease) ProjectilePressedCommand(tick: tick),
                if (phase == hz * 3) SpellPressedCommand(tick: tick),
              ]);
              direct.stepOneTick();
              final snapshot = direct.buildSnapshot();
              sawShot |= snapshot.entities.any(
                (e) => e.kind == EntityKind.projectile,
              );
              sawCharge |= snapshot.hud.chargeActive;
              direct.drainEvents();
            }
            final result = runReplaySimulation(
              core: replayed,
              totalTicks: hz * 12,
              commandStream: frames,
              onCheckpoint: (tick) =>
                  expect(_signature(replayed), checkpoints[tick]),
            );
            expect(result.ticksExecuted, hz * 12);
            expect(sawShot, isTrue);
            expect(sawCharge, isTrue);
            expect(_signature(replayed), _signature(direct));
          },
        );
      }
    }
  }
}

GameCore _core(int hz, String spell, String shot) => GameCore(
  seed: 98,
  playerCharacter: PlayerCharacterRegistry.eloise,
  tickHz: hz,
  equippedLoadoutOverride: EquippedLoadoutDef(
    abilityPrimaryId: 'eloise.bloodletter_cleave',
    abilityProjectileId: 'eloise.$shot',
    abilitySpellId: 'eloise.$spell',
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
    s.hud.chargeTier,
    s.hud.riposteTicksLeft,
    for (final e in s.entities)
      (
        e.id,
        e.projectileId,
        e.pos.x,
        e.pos.y,
        e.anim,
        e.animFrame,
        e.statusVisualMask,
      ),
  ];
}
