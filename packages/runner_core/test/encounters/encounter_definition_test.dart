import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_limits.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:test/test.dart';

EncounterDefinition warriorRescueFixture({int? points}) => EncounterDefinition(
  id: 'camp_rescue',
  name: 'Camp rescue',
  trigger: EncounterTrigger(x: 32, y: -256, width: 96, height: 512),
  npcs: [EncounterNpcPlacement(id: 'warrior', npcId: NpcId.warrior, x: 240)],
  enemies: [
    EncounterEnemyPlacement(id: 'guard', enemyId: EnemyId.grojib, x: 360),
  ],
  pointsPerNpc: points,
);

void main() {
  test(
    'complete warrior fixture admits one chunk with immutable ownership',
    () {
      final fixture = warriorRescueFixture();
      fixture.validateForChunk(600);
      expect(() => fixture.npcs.clear(), throwsUnsupportedError);
      expect(fixture.pointsPerNpc, isNull);
      expect(warriorRescueFixture(points: 0).pointsPerNpc, 0);
      expect(warriorRescueFixture(points: 250).pointsPerNpc, 250);
    },
  );
  test('incomplete drafts save but cannot become playable', () {
    final draft = EncounterDefinition(
      id: 'draft',
      name: 'Draft',
      trigger: EncounterTrigger(x: 0, y: 0, width: 20, height: 20),
    );
    draft.validateForChunk(600, requireComplete: false);
    expect(() => draft.validateForChunk(600), throwsArgumentError);
    expect(
      () => warriorRescueFixture().validateForChunk(300),
      throwsArgumentError,
    );
  });
  test('swept activation cannot skip a narrow trigger and includes edges', () {
    final trigger = EncounterTrigger(x: 100, y: 10, width: 2, height: 20);
    expect(trigger.intersectsSweep(0, 20, 200, 20), isTrue);
    expect(trigger.intersectsSweep(100, 10, 100, 10), isTrue);
    expect(trigger.intersectsSweep(0, 0, 200, 0), isFalse);
    expect(trigger.intersectsSweep(200, 20, 0, 20), isTrue);
  });
  test('runtime numeric guards reject unsafe awards without assertions', () {
    expect(() => warriorRescueFixture(points: -1), throwsArgumentError);
    expect(
      () => warriorRescueFixture(points: EncounterLimits.maxPointsPerNpc + 1),
      throwsArgumentError,
    );
    expect(EncounterLimits.addAward(500, survivors: 2, points: 250), 1000);
    expect(
      () => EncounterLimits.addAward(
        EncounterLimits.maxExactScore,
        survivors: 1,
        points: 1,
      ),
      throwsStateError,
    );
    expect(
      () => EncounterTrigger(x: double.nan, y: 0, width: 2, height: 2),
      throwsArgumentError,
    );
  });
}
