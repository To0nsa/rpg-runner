import 'dart:math' as math;

import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:test/test.dart';

import '../test_support/boss_resource_supply_fixture.dart';

void main() {
  for (final character in [
    PlayerCharacterRegistry.eloise,
    PlayerCharacterRegistry.eloiseWip,
  ]) {
    for (final hz in [30, 60, 90]) {
      test('${character.id.name} earns and collects Goddess supply at $hz Hz', () {
        final core = bossResourceSupplyCore(hz: hz, character: character);
        int? gemId;
        int? variant;
        var collected = false;
        for (var n = 0; n < hz * 90 && !core.gameOver; n++) {
          final before = core.buildSnapshot();
          core.applyCommands(bossResourceSupplyCommands(core));
          core.stepOneTick();
          final after = core.buildSnapshot();
          final gem = resourceGem(core);
          if (gemId == null && gem != null) {
            expect(after.bossArena!.phase, BossArenaPhase.combat);
            expect(
              after.bossArena!.hp100 * 2,
              lessThanOrEqualTo(after.bossArena!.hpMax100),
            );
            expect(
              gem.pos.x,
              inInclusiveRange(
                after.bossArena!.minX + 8,
                after.bossArena!.maxX - 8,
              ),
            );
            gemId = gem.id;
            variant = gem.pickupVariant;
            final manaIsLower =
                after.hud.mana * after.hud.staminaMax <=
                after.hud.stamina * after.hud.manaMax;
            expect(
              variant,
              manaIsLower
                  ? PickupVariant.restorationMana
                  : PickupVariant.restorationStamina,
            );
            core.paused = true;
            final pausedTick = core.tick;
            for (var pause = 0; pause < 5; pause++) {
              core.stepOneTick();
            }
            expect(core.tick, pausedTick);
            expect(resourceGem(core)!.id, gemId);
            core.paused = false;
          } else if (gemId != null && gem == null) {
            expect(after.bossArena!.phase, BossArenaPhase.combat);
            final isMana = variant == PickupVariant.restorationMana;
            final previous = isMana ? before.hud.mana : before.hud.stamina;
            final maximum = isMana ? before.hud.manaMax : before.hud.staminaMax;
            final actual = isMana ? after.hud.mana : after.hud.stamina;
            expect(actual, math.min(maximum, previous + maximum * .3));
            expect(actual, greaterThan(previous));
            collected = true;
            break;
          } else if (gem != null) {
            expect(gem.id, gemId);
            expect(gem.pickupVariant, variant);
          }
        }
        expect(
          gemId,
          isNotNull,
          reason:
              'HP=${core.buildSnapshot().bossArena?.hp100}, tick=${core.tick}',
        );
        expect(collected, isTrue);
      });
    }
  }
}
