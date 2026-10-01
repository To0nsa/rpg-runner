import 'package:runner_core/commands/command.dart';
import 'package:runner_core/encounters/encounter_instance.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/npc_section_guard_scenario.dart';

void main() {
  test('guard in later terrain survives retirement of its original chunk', () {
    final core = sectionGuardCore();
    var rescued = false;
    var advanceCamera = false;
    var originWasPublished = false;
    var originRetired = false;
    int? actorId;
    for (var t = 0; t < 1800 && !core.gameOver; t++) {
      core.applyCommands([
        if (!rescued || advanceCamera)
          StrikePressedCommand(tick: core.tick + 1),
        if (advanceCamera) MoveAxisCommand(tick: core.tick + 1, axis: 1),
      ]);
      core.stepOneTick();
      for (final event
          in core.drainEvents().whereType<EncounterResolvedEvent>()) {
        expect(rescued, isFalse);
        expect(event.outcome.reason, EncounterEndReason.rescued);
        rescued = true;
      }
      final snapshot = core.buildSnapshot();
      final hasOrigin = snapshot.stagedTerrainRenderSnapshot!.polygons.any(
        (polygon) => polygon.sourceId.chunkIndex == 0,
      );
      originWasPublished |= hasOrigin;
      final actors = snapshot.entities.where((e) => e.npcId == NpcId.warrior);
      if (actors.isEmpty) break;
      final npc = actors.single;
      actorId ??= npc.id;
      advanceCamera |= rescued && npc.pos.x > 600 && npc.anim == AnimKey.strike;
      if (originWasPublished && !hasOrigin) {
        expect(npc.id, actorId);
        expect(npc.pos.x, greaterThan(600));
        expect(npc.npcHealth!.hp100, greaterThan(0));
        expect(npc.npcHealth!.protected, isFalse);
        originRetired = true;
        break;
      }
    }
    expect(originWasPublished, isTrue);
    expect(originRetired, isTrue);
    core.giveUp();
    final stats = core.drainEvents().whereType<RunEndedEvent>().single.stats;
    expect((stats.rescuedNpcs, stats.rescuePoints), (1, 250));
  });

  for (final id in NpcId.values) {
    test(
      '${id.name} clears rescue then continuously crosses the chunk seam to fight a section enemy',
      () {
        final core = sectionGuardCore(npcId: id);
        EncounterOutcome? outcome;
        var maxX = 0.0;
        var damagedAfterRescue = false;
        var attackedAfterRescue = false;
        int? actorId;
        int? hpAtRescue;
        for (var t = 0; t < 900 && !core.gameOver; t++) {
          core.applyCommands([
            if (outcome == null) StrikePressedCommand(tick: core.tick + 1),
          ]);
          core.stepOneTick();
          for (final event
              in core.drainEvents().whereType<EncounterResolvedEvent>()) {
            expect(outcome, isNull, reason: 'Rescue must resolve only once.');
            outcome = event.outcome;
          }
          final actors = core.buildSnapshot().entities.where(
            (e) => e.npcId == id,
          );
          if (actors.isEmpty) break;
          final npc = actors.single;
          actorId ??= npc.id;
          expect(npc.id, actorId);
          if (npc.pos.x > maxX) maxX = npc.pos.x;
          expect(
            npc.pos.x +
                const NpcCatalog().get(id).collider.halfX +
                const NpcCatalog().get(id).collider.offsetX.abs(),
            lessThanOrEqualTo(1800),
          );
          if (outcome != null) {
            expect(npc.npcHealth!.protected, isFalse);
            hpAtRescue ??= npc.npcHealth!.hp100;
            damagedAfterRescue |= npc.npcHealth!.hp100 < hpAtRescue;
            attackedAfterRescue |=
                npc.pos.x > 600 &&
                (npc.anim == AnimKey.strike || npc.anim == AnimKey.cast);
          }
          if (attackedAfterRescue && damagedAfterRescue) break;
        }
        expect(outcome?.reason, EncounterEndReason.rescued);
        expect(maxX, greaterThan(600));
        expect(attackedAfterRescue, isTrue);
        expect(damagedAfterRescue, isTrue);
        core.giveUp();
        final stats = core
            .drainEvents()
            .whereType<RunEndedEvent>()
            .single
            .stats;
        expect((stats.rescuedNpcs, stats.rescuePoints), (1, 250));
      },
    );
  }
}
