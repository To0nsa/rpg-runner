import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:test/test.dart';

import '../test_support/world_interaction_run_fixture.dart';

void main() {
  for (final character in PlayerCharacterRegistry.all) {
    for (final hz in [30, 60, 120]) {
      test(
        '${character.id} real top contact and captured Play agree at $hz Hz',
        () {
          final app = worldInteractionRunCore(character, tickHz: hz);
          final editor = worldInteractionRunCore(
            character,
            editor: true,
            tickHz: hz,
          );
          expect(app.buildSnapshot().interactions, isNotEmpty);
          expect(app.buildSnapshot().hud.blessings, isEmpty);
          int? firstGrant;
          for (var tick = 1; tick <= hz * 2; tick++) {
            final commands = <Command>[
              if (tick == hz) JumpPressedCommand(tick: tick),
            ];
            app.applyCommands(commands);
            editor.applyCommands(commands);
            app.stepOneTick();
            editor.stepOneTick();
            expect(
              worldInteractionRunState(editor),
              worldInteractionRunState(app),
              reason: 'tick $tick',
            );
            final blessings = app.buildSnapshot().hud.blessings;
            if (blessings.isNotEmpty) {
              firstGrant ??= tick;
              expect(blessings.single.grantedAtTick, firstGrant);
            }
          }
          expect(app.buildSnapshot().interactions.first.active, isTrue);
          app.paused = true;
          final frozen = worldInteractionRunState(app);
          for (var i = 0; i < hz; i++) {
            app.stepOneTick();
          }
          expect(worldInteractionRunState(app), frozen);
          app.paused = false;
          app.giveUp();
          final ended = worldInteractionRunState(app);
          app.stepOneTick();
          expect(worldInteractionRunState(app), ended);
          final restarted = worldInteractionRunCore(character, tickHz: hz);
          expect(restarted.buildSnapshot().hud.blessings, isEmpty);
          expect(restarted.buildSnapshot().interactions.first.active, isFalse);
        },
      );
    }
  }

  test('falling onto the bowl activates only on actual top support', () {
    final core = worldInteractionRunCore(PlayerCharacterRegistry.eloise);
    var landed = false;
    for (var tick = 1; tick <= 180; tick++) {
      core.applyCommands(const []);
      core.stepOneTick();
      if (core.buildSnapshot().hud.blessings.isNotEmpty) {
        final support = core.buildTerrainPlayerDebugSnapshot()!;
        expect(support.grounded, isTrue);
        expect(support.supportPointYTicks, 160 * 1024);
        expect(
          support.supportEdgeId!.placementKey,
          contains('tiny_swords_fire_vasque_01'),
        );
        landed = true;
        break;
      }
    }
    expect(landed, isTrue);
  });

  test('falling onto the Field pot grants one blessing and Holy impact', () {
    // This seed loads the authored pot in the initial streamed window.
    final core = GameCore(
      seed: 16,
      levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
        noEnemyChunks: 9999,
        tuning: const CoreTuning(camera: CameraTuning(speedLagMulX: 0)),
      ),
      playerCharacter: PlayerCharacterRegistry.eloise,
      equippedLoadoutOverride: const EquippedLoadoutDef(),
    );
    final pot = core.buildSnapshot().interactions.single;
    core.setPlayerPosXYUnsafeForTest(pot.x, pot.y - 80);
    final impacts = <SpellImpactEvent>[];
    for (var tick = 1; tick <= 180; tick++) {
      core.applyCommands(const []);
      core.stepOneTick();
      impacts.addAll(core.drainEvents().whereType<SpellImpactEvent>());
      if (core.buildSnapshot().hud.blessings.isNotEmpty) break;
    }
    final support = core.buildTerrainPlayerDebugSnapshot()!;
    expect(support.grounded, isTrue);
    expect(support.supportPointYTicks, 176 * 1024);
    expect(
      support.supportEdgeId!.placementKey,
      contains('gandalf_hardcore_high_garden_pot_02'),
    );
    expect(core.buildSnapshot().interactions.single.active, isTrue);
    expect(core.buildSnapshot().hud.blessings, hasLength(1));
    expect(
      impacts.where(
        (event) => event.impactId == SpellImpactId.holyShrineBlessing,
      ),
      hasLength(1),
    );
  });
}
