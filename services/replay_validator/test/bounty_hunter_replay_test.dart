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
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  for (final gun in [
    ProjectileId.hunterPistol,
    ProjectileId.hunterCrossbow,
    ProjectileId.hunterShotgun,
  ]) {
    test(
      '$gun reproduces bombs, shots, melee and movement through replay encoding',
      () {
        final direct = _core(gun), replayed = _core(gun);
        final frames = <ReplayCommandFrameV1>[];
        var sawBomb = false, sawShot = false;
        final checkpoints = <int, List<Object?>>{};
        for (var tick = 1; tick <= 600; tick++) {
          if (tick == 1 || tick % 256 == 0)
            checkpoints[tick] = _signature(direct);
          final phase = tick % 240;
          final mask = switch (phase) {
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
            if (phase == 40) SecondaryPressedCommand(tick: tick),
            if (phase == 100) ProjectilePressedCommand(tick: tick),
            if (phase == 140) StrikePressedCommand(tick: tick),
            if (phase == 200 || phase == 210) JumpPressedCommand(tick: tick),
          ]);
          direct.stepOneTick();
          final snapshot = direct.buildSnapshot();
          sawBomb |= snapshot.entities.any(
            (e) => e.projectileId == ProjectileId.hunterBomb,
          );
          sawShot |= snapshot.entities.any((e) => e.projectileId == gun);
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
        expect(sawBomb, isTrue);
        expect(sawShot, isTrue);
        expect(_signature(replayed), _signature(direct));
        expect(
          replayed.playerCharacter.renderAnim.sourcesByKey.values.join(),
          contains(switch (gun) {
            ProjectileId.hunterCrossbow => '/crossbow/',
            ProjectileId.hunterShotgun => '/shotgun/',
            _ => '/gun/',
          }),
        );
      },
    );
  }
}

GameCore _core(ProjectileId gun) => GameCore(
  seed: 98,
  playerCharacter: PlayerCharacterRegistry.bountyHunter,
  equippedLoadoutOverride: EquippedLoadoutDef(
    mask: LoadoutSlotMask.all,
    mainWeaponId: WeaponId.hunterBlade,
    offhandWeaponId: WeaponId.hunterBombKit,
    spellBookId: SpellBookId.hunterFieldKit,
    projectileSlotSpellId: gun,
    abilityPrimaryId: 'bounty_hunter.threefold_cut',
    abilitySecondaryId: 'bounty_hunter.blast_bomb',
    abilityProjectileId: 'bounty_hunter.snap_shot',
    abilitySpellId: 'bounty_hunter.prepare_charges',
    abilityMobilityId: 'bounty_hunter.dash',
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
        e.anim,
        e.animFrame,
        e.statusVisualMask,
      ),
  ];
}
