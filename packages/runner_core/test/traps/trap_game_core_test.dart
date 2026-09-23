import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/trap_snapshot.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:test/test.dart';

import '../test_support/trap_run_fixture.dart';

void main() {
  test('eight concurrent spikes kill enemies and count each death once', () {
    final level = trapRunLevel(TrapId.spike).copyWith(
      noEnemyChunks: 0,
      chunkPatternSource: ChunkPatternListSource(
        easyPatterns: [],
        hardPatterns: [],
        normalPatterns: [
          ChunkPattern(
            name: 'field_flat',
            chunkKey: 'field_flat',
            traps: [
              for (var i = 0; i < 8; i++)
                TrapPlacement(
                  trapId: TrapId.spike,
                  x: 296 + i,
                  y: 220,
                  trigger: const TrapRect(-60, -70, 120, 90),
                ),
            ],
            spawnMarkers: const [
              SpawnMarker(
                enemyId: EnemyId.grojib,
                x: 300,
                chancePercent: 100,
                salt: 1,
                placement: SpawnPlacementMode.highestSurfaceAtX,
              ),
            ],
          ),
        ],
      ),
    );
    final core = GameCore(
      seed: trapRunSeed,
      levelDefinition: level,
      playerCharacter: PlayerCharacterRegistry.eloise,
      equippedLoadoutOverride: trapRunLoadout,
    );
    for (var tick = 0; tick < 160; tick++) {
      core.stepOneTick();
    }
    core.giveUp();
    final ended = core.drainEvents().whereType<RunEndedEvent>().last;
    expect(ended.stats.enemyKillCounts[EnemyId.grojib.index], 1);
  });
  for (final character in PlayerCharacterRegistry.all) {
    for (final id in TrapId.values) {
      test('${character.id} $id app and Level Play agree on every tick', () {
        final app = trapRunCore(character, id),
            editor = trapRunCore(character, id, editor: true);
        expect(
          app.buildSnapshot().traps,
          isNotEmpty,
          reason: 'Prewarmed chunks own traps before tick one.',
        );
        var warning = false, active = false, dart = false, poison = false;
        final initialHp = app.buildSnapshot().hud.hp;
        for (var tick = 0; tick < 370; tick++) {
          app.stepOneTick();
          editor.stepOneTick();
          expect(trapRunState(editor), trapRunState(app), reason: 'tick $tick');
          final snapshot = app.buildSnapshot();
          warning |= snapshot.traps.any((t) => t.phase == TrapPhase.warning);
          active |= snapshot.traps.any((t) => t.phase == TrapPhase.active);
          dart |= snapshot.entities.any(
            (e) => e.projectileId == ProjectileId.poisonDart,
          );
          poison |=
              (snapshot.playerEntity!.statusVisualMask &
                  EntityStatusVisualMask.poison) !=
              0;
        }
        expect(warning && active, isTrue);
        if (id != TrapId.swingingAxe) {
          expect(app.buildSnapshot().hud.hp, lessThan(initialHp));
        }
        if (id == TrapId.poisonDarts) expect(dart && poison, isTrue);
      });
    }
  }
  test('pause and player death freeze trap animation and projectile state', () {
    final character = PlayerCharacterRegistry.eloise.copyWith(
      tuning: PlayerCharacterRegistry.eloise.tuning.copyWith(
        resource: const ResourceTuning(
          playerHpMax: 1,
          playerHpRegenPerSecond: 0,
        ),
      ),
    );
    final core = trapRunCore(character, TrapId.spike);
    core.stepOneTick();
    final before = trapRunState(core);
    core.paused = true;
    for (var i = 0; i < 90; i++) {
      core.stepOneTick();
    }
    expect(trapRunState(core), before);
    core.paused = false;
    RunEndedEvent? end;
    for (var i = 0; i < 180; i++) {
      core.stepOneTick();
      for (final event in core.drainEvents()) {
        if (event is RunEndedEvent) end = event;
      }
    }
    expect(end?.reason, RunEndReason.playerDied);
    expect(end?.deathInfo?.sourceTrap?.trapId, TrapId.spike);
    final frozen = trapRunState(core);
    for (var i = 0; i < 90; i++) {
      core.stepOneTick();
    }
    expect(trapRunState(core), frozen);
  });
}
