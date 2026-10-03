import 'package:test/test.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  for (final level in [LevelId.field, LevelId.forest]) {
    test(
      'actor projection matches full snapshots without changing $level gameplay',
      () {
        GameCore create() => GameCore(
          seed: 1337,
          levelDefinition: LevelRegistry.byId(level),
          playerCharacter: PlayerCharacterRegistry.eloise,
        );
        final reference = create();
        final projected = create();
        final initial = projected.buildActorFrameSnapshot();
        expect(() => initial.entities.clear(), throwsUnsupportedError);
        for (var tick = 0; tick <= 180; tick++) {
          final full = reference.buildSnapshot();
          final frame = projected.buildActorFrameSnapshot();
          expect(frame.tick, full.tick);
          expect(frame.distance, full.distance);
          expect(frame.gameOver, full.gameOver);
          final actors = full.entities.where(
            (e) =>
                e.kind == EntityKind.player ||
                e.kind == EntityKind.enemy ||
                e.kind == EntityKind.npc ||
                e.kind == EntityKind.projectile,
          );
          expect(frame.entities.map(_fields), actors.map(_fields));
          expect(
            projected.buildSnapshot().entities.map(_fields),
            full.entities.map(_fields),
          );
          expect(
            projected.drainEvents().map((e) => e.runtimeType),
            reference.drainEvents().map((e) => e.runtimeType),
          );
          if (full.gameOver || tick == 180) break;
          final next = tick + 1;
          final commands = <Command>[
            MoveAxisCommand(tick: next, axis: 1),
            if (next % 45 == 0) JumpPressedCommand(tick: next),
            if (next % 35 == 0) ProjectilePressedCommand(tick: next),
            if (next % 60 == 0) StrikePressedCommand(tick: next),
          ];
          reference.applyCommands(commands);
          projected.applyCommands(commands);
          reference.stepOneTick();
          projected.stepOneTick();
        }
        expect(initial.tick, 0);
        reference.giveUp();
        projected.giveUp();
        expect(projected.buildActorFrameSnapshot().gameOver, isTrue);
        expect(
          projected.buildActorFrameSnapshot().entities.map(_fields),
          reference
              .buildSnapshot()
              .entities
              .where(
                (e) =>
                    e.kind == EntityKind.player ||
                    e.kind == EntityKind.enemy ||
                    e.kind == EntityKind.npc ||
                    e.kind == EntityKind.projectile,
              )
              .map(_fields),
        );
      },
    );
  }
}

Object _fields(EntityRenderSnapshot e) => (
  e.id,
  e.kind,
  e.pos.x,
  e.pos.y,
  e.vel?.x,
  e.vel?.y,
  e.size?.x,
  e.size?.y,
  e.enemyId,
  e.npcId,
  e.npcHealth?.hp100,
  e.npcHealth?.maxHp100,
  e.npcHealth?.protected,
  e.npcHealth?.guarding,
  e.projectileId,
  e.pickupVariant,
  e.z,
  e.rotationRad,
  e.isSwimming,
  e.waterImmersion1000,
  e.facing,
  e.artFacingDir,
  e.grounded,
  e.anim,
  e.animFrame,
  e.statusVisualMask,
  e.controlLockMask,
);
