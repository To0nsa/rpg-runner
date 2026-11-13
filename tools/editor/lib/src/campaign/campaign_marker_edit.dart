import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import '../chunks/chunk_encounter_edit.dart';

/// A view of legacy mission markers and stable new placements through one editor.
/// Legacy list indices are valid only against the captured mission revision.
final class CampaignMarkerEntry {
  const CampaignMarkerEntry(
    this.key,
    this.position, {
    this.placement,
    this.region,
  });
  final String key;
  final CampaignPoint position;
  final CampaignPlacementSource? placement;
  final CampaignRegion? region;
}

List<CampaignMarkerEntry> campaignMarkerEntries(
  CampaignMissionSource mission,
) => [
  if (mission.start != null) CampaignMarkerEntry('start', mission.start!),
  if (mission.exit != null)
    CampaignMarkerEntry('exit', mission.exit!.origin, region: mission.exit),
  for (final (i, p) in mission.collectibles.indexed)
    CampaignMarkerEntry('collectibles:$i', p),
  for (final (i, r) in mission.requiredRegions.indexed)
    CampaignMarkerEntry('requiredRegions:$i', r.origin, region: r),
  for (final p in mission.placements)
    CampaignMarkerEntry('placement:${p.id}', p.position, placement: p),
];

CampaignPlacementSource moveCampaignPlacement(
  CampaignPlacementSource value,
  CampaignPoint point,
) => switch (value) {
  CampaignPickupSource p => CampaignPickupSource(
    p.id,
    point,
    resource: p.resource,
  ),
  CampaignEnemySource p => CampaignEnemySource(
    p.id,
    point,
    required: p.required,
    returnWhenPlayerRetreats: p.returnWhenPlayerRetreats,
    marker: SpawnMarker(
      enemyId: p.marker.enemyId,
      x: point.x,
      chancePercent: p.marker.chancePercent,
      salt: p.marker.salt,
      placement: p.marker.placement,
    ),
  ),
  CampaignTrapSource p => CampaignTrapSource(
    p.id,
    point.missionChunkId,
    p.trap.copyWith(x: point.x.round(), y: point.y.round()),
  ),
  CampaignRescueSource p => CampaignRescueSource(
    p.id,
    point.missionChunkId,
    translateCampaignRescue(
      p.encounter,
      point.x - p.position.x,
      point.y - p.position.y,
    ),
    required: p.required,
  ),
  CampaignShrineSource p => CampaignShrineSource(
    p.id,
    point,
    prefabKey: p.prefabKey,
    placementKey: p.placementKey,
    shapeId: p.shapeId,
    appearance: p.appearance,
    activationWidth: p.activationWidth,
    scale: p.scale,
  ),
};

EncounterDefinition translateCampaignRescue(
  EncounterDefinition group,
  double dx,
  double dy,
) => editEncounter(
  group,
  trigger: EncounterTrigger(
    x: group.trigger.x + dx,
    y: group.trigger.y + dy,
    width: group.trigger.width,
    height: group.trigger.height,
  ),
  npcs: group.npcs.map((p) => editEncounterNpc(p, x: p.x + dx)),
  enemies: group.enemies.map((p) => editEncounterEnemy(p, x: p.x + dx)),
);

/// Reuses the mission's revision-checked replacement command. Moving local
/// targets also rebinds any existing explicit objective references atomically.
Map<String, Object?> replaceCampaignMarker(
  CampaignMissionSource mission,
  CampaignMarkerEntry? before,
  CampaignMarkerEntry after,
) {
  final json = mission.toJson();
  final p = after.placement;
  if (p != null) {
    final placements = [...mission.placements];
    final index = placements.indexWhere((v) => v.id == before?.placement?.id);
    if (before != null && index < 0) {
      throw StateError('Marker changed; select it again.');
    }
    if (index < 0) {
      placements.add(p);
    } else {
      placements[index] = p;
    }
    json['placements'] = placements.map((v) => v.toJson()).toList();
    final old = before?.placement;
    if (old is CampaignEnemySource && p is CampaignEnemySource) {
      json['requiredEnemies'] = [
        for (final target in mission.requiredEnemies)
          {
            'missionChunkId':
                target.missionChunkId == old.missionChunkId &&
                    target.markerSalt == old.marker.salt
                ? p.missionChunkId
                : target.missionChunkId,
            'markerSalt':
                target.missionChunkId == old.missionChunkId &&
                    target.markerSalt == old.marker.salt
                ? p.marker.salt
                : target.markerSalt,
          },
      ];
    }
    if (old is CampaignRescueSource && p is CampaignRescueSource) {
      json['requiredRescues'] = [
        for (final target in mission.requiredRescues)
          {
            'missionChunkId':
                target.missionChunkId == old.missionChunkId &&
                    target.encounterId == old.encounter.id
                ? p.missionChunkId
                : target.missionChunkId,
            'encounterId': target.encounterId,
          },
      ];
    }
  } else {
    final value = after.region == null
        ? campaignPointToJson(after.position)
        : campaignRegionToJson(after.region!);
    final parts = after.key.split(':');
    if (parts.length == 1) {
      json[parts.single] = value;
    } else {
      final list = json[parts.first] as List;
      if (before == null) {
        list.add(value);
      } else {
        list[int.parse(parts.last)] = value;
      }
    }
  }
  return json;
}

Map<String, Object?> removeCampaignMarker(
  CampaignMissionSource mission,
  CampaignMarkerEntry entry,
) {
  final json = mission.toJson();
  final p = entry.placement;
  if (p != null) {
    // Required is part of the placed object; deleting it also removes its own
    // objective. Explicit legacy references are removed in the same transaction.
    json['placements'] = mission.placements
        .where((v) => v.id != p.id)
        .map((v) => v.toJson())
        .toList();
    if (p is CampaignEnemySource) {
      (json['requiredEnemies'] as List).removeWhere(
        (v) =>
            v['missionChunkId'] == p.missionChunkId &&
            v['markerSalt'] == p.marker.salt,
      );
    }
    if (p is CampaignRescueSource) {
      (json['requiredRescues'] as List).removeWhere(
        (v) =>
            v['missionChunkId'] == p.missionChunkId && v['encounterId'] == p.id,
      );
    }
  } else {
    final parts = entry.key.split(':');
    if (parts.length == 1) {
      json[parts.single] = null;
    } else {
      (json[parts.first] as List).removeAt(int.parse(parts.last));
    }
  }
  return json;
}

/// Enemy salt is an objective identity. Allocate against all source and local
/// markers so moving/duplicating an object cannot accidentally rebind a target.
int allocateCampaignEnemySalt(
  CampaignMissionSource mission,
  Iterable<int> inherited,
) {
  final used = {
    ...inherited,
    ...mission.placements.whereType<CampaignEnemySource>().map(
      (p) => p.marker.salt,
    ),
  };
  for (var salt = 0; salt <= 2147483647; salt++) {
    if (!used.contains(salt)) return salt;
  }
  throw StateError('No enemy marker identities remain.');
}

/// Allocates the first unused mission_chunk_N for both append and duplicate.
/// Existing route identities and their references remain unchanged.
String nextMissionChunkId(CampaignMissionSource mission) {
  var suffix = 1;
  while (mission.route.any((o) => o.id == 'mission_chunk_$suffix')) {
    suffix++;
  }
  return 'mission_chunk_$suffix';
}

/// Ordinary route duplication copies local gameplay with new identities. Start
/// and exit remain mission singletons; shared chunk sources are never rewritten.
Map<String, Object?> duplicateCampaignMissionChunk(
  CampaignMissionSource mission,
  int index,
) {
  final original = mission.route[index];
  final missionChunk = nextMissionChunkId(mission);
  final json = mission.toJson();
  (json['route'] as List).insert(index + 1, {
    'id': missionChunk,
    'levelId': original.levelId,
    'chunkKey': original.chunkKey,
  });
  CampaignPoint point(CampaignPoint p) =>
      CampaignPoint(missionChunkId: missionChunk, x: p.x, y: p.y);
  final ids = mission.placements.map((p) => p.id).toSet();
  final rescueIds = <String, String>{};
  final copies = <CampaignPlacementSource>[];
  for (final p in mission.placements.where(
    (p) => p.missionChunkId == original.id,
  )) {
    final id = nextEncounterSourceId(p.id, ids);
    ids.add(id);
    final data = moveCampaignPlacement(p, point(p.position)).toJson()
      ..['id'] = id;
    if (p is CampaignRescueSource) {
      (data['encounter'] as Map)['id'] = id;
      rescueIds[p.id] = id;
    }
    copies.add(decodeCampaignPlacements([data]).single);
  }
  if (copies.isNotEmpty) {
    json['placements'] = [
      ...mission.placements,
      ...copies,
    ].map((p) => p.toJson()).toList();
  }
  json['collectibles'] = [
    ...json['collectibles'] as List,
    for (final p in mission.collectibles.where(
      (p) => p.missionChunkId == original.id,
    ))
      campaignPointToJson(point(p)),
  ];
  json['requiredRegions'] = [
    ...json['requiredRegions'] as List,
    for (final r in mission.requiredRegions.where(
      (r) => r.origin.missionChunkId == original.id,
    ))
      campaignRegionToJson(
        CampaignRegion(
          origin: point(r.origin),
          width: r.width,
          height: r.height,
        ),
      ),
  ];
  json['requiredEnemies'] = [
    ...json['requiredEnemies'] as List,
    for (final e in mission.requiredEnemies.where(
      (e) => e.missionChunkId == original.id,
    ))
      {'missionChunkId': missionChunk, 'markerSalt': e.markerSalt},
  ];
  json['requiredRescues'] = [
    ...json['requiredRescues'] as List,
    for (final e in mission.requiredRescues.where(
      (e) => e.missionChunkId == original.id,
    ))
      {
        'missionChunkId': missionChunk,
        'encounterId': rescueIds[e.encounterId] ?? e.encounterId,
      },
  ];
  return json;
}
