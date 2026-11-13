import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_editor/src/campaign/campaign_marker_edit.dart';

void main() {
  CampaignMissionSource fixture() => CampaignMissionSource.decode({
    'id': 'test',
    'revision': 1,
    'includeInBuild': false,
    'title': {'en': 'Test', 'fr': 'Test'},
    'description': {'en': 'Test', 'fr': 'Test'},
    'visualThemeId': 'forest',
    'levelId': 'forest',
    'firstClearXp': 0,
    'firstClearGold': 0,
    'firstClearItems': [],
    'route': [
      for (final id in ['first', 'second'])
        {'id': id, 'levelId': 'forest', 'chunkKey': 'shared'},
    ],
    'start': null,
    'exit': null,
    'collectibles': [],
    'requiredRegions': [],
    'requiredEnemies': [
      {'missionChunkId': 'first', 'markerSalt': 5},
    ],
    'requiredRescues': [
      {'missionChunkId': 'first', 'encounterId': 'rescue'},
    ],
    'placements': [
      CampaignEnemySource(
        'guard',
        CampaignPoint(missionChunkId: 'first', x: 150, y: 224),
        marker: const SpawnMarker(
          enemyId: EnemyId.grojib,
          x: 150,
          salt: 5,
          chancePercent: 100,
        ),
        required: false,
      ).toJson(),
      CampaignRescueSource(
        'rescue',
        'first',
        EncounterDefinition(
          id: 'rescue',
          name: 'Rescue',
          trigger: EncounterTrigger(x: 100, y: 100, width: 100, height: 100),
          npcs: [
            EncounterNpcPlacement(id: 'npc', npcId: NpcId.warrior, x: 125),
          ],
          enemies: [
            EncounterEnemyPlacement(
              id: 'enemy',
              enemyId: EnemyId.grojib,
              x: 175,
            ),
          ],
        ),
        required: false,
      ).toJson(),
    ],
  });

  test('moving and copying a following enemy preserves its return switch', () {
    final original = fixture();
    final json = original.toJson();
    ((json['placements'] as List).first
            as Map<String, Object?>)['returnWhenPlayerRetreats'] =
        false;
    final source = CampaignMissionSource.decode(json);
    final enemy = source.placements.first as CampaignEnemySource;
    final moved = moveCampaignPlacement(
      enemy,
      CampaignPoint(missionChunkId: 'second', x: 200, y: 224),
    ) as CampaignEnemySource;
    expect(moved.returnWhenPlayerRetreats, isFalse);
    expect(moved.marker.salt, enemy.marker.salt);
    final copy = CampaignMissionSource.decode(
      duplicateCampaignMissionChunk(source, 0),
    );
    expect(
      copy.placements.whereType<CampaignEnemySource>().every(
        (p) => !p.returnWhenPlayerRetreats,
      ),
      isTrue,
    );
    expect(
      (original.placements.first as CampaignEnemySource)
          .returnWhenPlayerRetreats,
      isTrue,
    );
  });

  test(
    'moving a local enemy rebinds explicit objectives including edited salt',
    () {
      final source = fixture(), before = campaignMarkerEntries(fixture()).first;
      final value = CampaignEnemySource(
        'guard',
        CampaignPoint(missionChunkId: 'second', x: 200, y: 224),
        marker: const SpawnMarker(
          enemyId: EnemyId.grojib,
          x: 200,
          salt: 9,
          chancePercent: 100,
        ),
        required: false,
      );
      final moved = CampaignMissionSource.decode(
        replaceCampaignMarker(
          source,
          before,
          CampaignMarkerEntry(before.key, value.position, placement: value),
        ),
      );
      expect(moved.requiredEnemies.single, (
        missionChunkId: 'second',
        markerSalt: 9,
      ));
      expect(moved.placements.first.id, 'guard');
      final removed = CampaignMissionSource.decode(
        removeCampaignMarker(moved, campaignMarkerEntries(moved).first),
      );
      expect(removed.requiredEnemies, isEmpty);
      expect(removed.requiredRescues, source.requiredRescues);
      expect(source.requiredEnemies.single, (
        missionChunkId: 'first',
        markerSalt: 5,
      ));
    },
  );

  test('rescue movement translates members and route duplication remaps objectives', () {
    final source = fixture();
    final before = campaignMarkerEntries(source).last;
    final moved = moveCampaignPlacement(
      before.placement!,
      CampaignPoint(missionChunkId: 'second', x: 140, y: 120),
    ) as CampaignRescueSource;
    expect(moved.encounter.npcs.single.x, 165);
    expect(moved.encounter.enemies.single.x, 215);
    final changed = CampaignMissionSource.decode(
      replaceCampaignMarker(
        source,
        before,
        CampaignMarkerEntry(before.key, moved.position, placement: moved),
      ),
    );
    expect(changed.requiredRescues.single, (
      missionChunkId: 'second',
      encounterId: 'rescue',
    ));
    final copy = CampaignMissionSource.decode(
      duplicateCampaignMissionChunk(source, 0),
    );
    expect(copy.route.map((o) => o.id), ['first', 'mission_chunk_1', 'second']);
    expect(copy.placements.map((p) => p.id).toSet(), hasLength(4));
    final copiedRescue = copy.placements.last as CampaignRescueSource;
    expect(copiedRescue.encounter.id, copiedRescue.id);
    expect(copy.requiredRescues.last, (
      missionChunkId: 'mission_chunk_1',
      encounterId: copiedRescue.id,
    ));
    expect(copy.requiredEnemies.last, (
      missionChunkId: 'mission_chunk_1',
      markerSalt: 5,
    ));
    expect(source.route, hasLength(2));
    final json = copy.toJson();
    (json['route'] as List).insert(0, (json['route'] as List).removeLast());
    expect(
      CampaignMissionSource.decode(json).placements.last.missionChunkId,
      'mission_chunk_1',
    );
    final secondCopy = CampaignMissionSource.decode(
      duplicateCampaignMissionChunk(copy, 0),
    );
    expect(secondCopy.route.map((o) => o.id), [
      'first',
      'mission_chunk_2',
      'mission_chunk_1',
      'second',
    ]);
  });
}
