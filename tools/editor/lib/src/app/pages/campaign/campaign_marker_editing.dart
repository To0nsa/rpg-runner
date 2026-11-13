import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/ecs/stores/restoration_item_store.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_placement.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../../campaign/campaign_domain_plugin.dart';
import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_encounter_edit.dart';
import '../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../domain/authoring_types.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/terrain_polygon_exact_edit_controller.dart';

enum CampaignMarkerTool { select, place, move }

enum CampaignMarkerBrush {
  none,
  gold,
  health,
  mana,
  stamina,
  shrine,
  enemy,
  trap,
  rescue,
  start,
  exit,
  visit,
}

/// Coordinates transient scene/form state with the existing Campaign command.
/// It never writes files or owns a second mission document/history.
final class CampaignMarkerEditing extends ChangeNotifier {
  CampaignMarkerEditing(this.session);
  final EditorSessionController session;
  final exact = TerrainPolygonExactEditController();
  CampaignDocument? _document;
  Map<String, PolygonTerrainRuntimeChunk> compiled = {};
  CampaignDocument get document => _document!;
  CampaignMissionSource get mission => document.selected;
  CampaignMarkerTool tool = CampaignMarkerTool.select;
  CampaignMarkerBrush brush = CampaignMarkerBrush.none;
  EnemyId enemy = EnemyId.grojib;
  TrapId trap = TrapId.spike;
  WorldInteractionAppearanceId appearance =
      WorldInteractionAppearanceId.emberFlame;
  bool snap = true;
  int trapFrame = 0;
  String? selectedKey, memberId, error;
  CampaignMarkerEntry? candidate;
  bool gestureActive = false;
  bool get hasDraft => gestureActive || exact.hasChanges;
  List<CampaignMarkerEntry> get entries => campaignMarkerEntries(mission);

  /// Sidebar filtering follows the library choice, independently of scene
  /// selection and tools. The scene still uses the complete [entries] list.
  List<CampaignMarkerEntry> get placedEntries => entries.where((entry) {
    final placement = entry.placement;
    return switch (brush) {
      CampaignMarkerBrush.none => true,
      CampaignMarkerBrush.gold =>
        (placement is CampaignPickupSource && placement.resource == null) ||
            entry.key.startsWith('collectibles:'),
      CampaignMarkerBrush.health ||
      CampaignMarkerBrush.mana ||
      CampaignMarkerBrush.stamina =>
        placement is CampaignPickupSource &&
            placement.resource?.name == brush.name,
      CampaignMarkerBrush.shrine => placement is CampaignShrineSource,
      CampaignMarkerBrush.enemy => placement is CampaignEnemySource,
      CampaignMarkerBrush.trap => placement is CampaignTrapSource,
      CampaignMarkerBrush.rescue => placement is CampaignRescueSource,
      CampaignMarkerBrush.start => entry.key == 'start',
      CampaignMarkerBrush.exit => entry.key == 'exit',
      CampaignMarkerBrush.visit => entry.key.startsWith('requiredRegions:'),
    };
  }).toList();

  CampaignMarkerEntry? get selected =>
      entries.where((e) => e.key == selectedKey).firstOrNull;

  void bind(
    CampaignDocument value,
    Map<String, PolygonTerrainRuntimeChunk> chunks,
  ) {
    if (_document?.selectedMissionId != value.selectedMissionId) {
      selectedKey = null;
      memberId = null;
    }
    if (!identical(value, _document)) {
      candidate = null;
      gestureActive = false;
    }
    _document = value;
    compiled = chunks;
    if (selected == null) selectedKey = null;
  }

  bool finishDraft() => !gestureActive && exact.save();
  void changed() => notifyListeners();
  void cancel() {
    candidate = null;
    gestureActive = false;
    exact.discard();
    tool = CampaignMarkerTool.select;
    error = null;
    notifyListeners();
  }

  /// Chooses the library filter and arms placement, or selection for None.
  /// Resolves fields first; false keeps the current tool and panel visible so
  /// the author can correct a blocked draft.
  bool choose(CampaignMarkerBrush value) {
    if (!finishDraft()) return false;
    brush = value;
    tool = value == CampaignMarkerBrush.none
        ? CampaignMarkerTool.select
        : CampaignMarkerTool.place;
    error = null;
    candidate = null;
    notifyListeners();
    return true;
  }

  void select(String? key, {String? participant}) {
    if (!finishDraft()) return;
    selectedKey = key;
    memberId = participant;
    tool = CampaignMarkerTool.select;
    candidate = null;
    error = null;
    notifyListeners();
  }

  String id(String base) => nextEncounterSourceId(base, [
    ...mission.placements.map((p) => p.id),
    for (final c in document.chunks.chunks) ...c.encounters.map((e) => e.id),
  ]);
  int salt() => allocateCampaignEnemySalt(
    mission,
    document.chunks.chunks.expand((c) => c.markers.map((m) => m.salt)),
  );

  CampaignMarkerEntry create(CampaignPoint point) {
    if (brush == CampaignMarkerBrush.none) {
      throw StateError('Choose a marker from the library before placing.');
    }
    final name = id(brush.name);
    final CampaignPlacementSource? placement = switch (brush) {
      CampaignMarkerBrush.gold => CampaignPickupSource(name, point),
      CampaignMarkerBrush.health ||
      CampaignMarkerBrush.mana ||
      CampaignMarkerBrush.stamina => CampaignPickupSource(
        name,
        point,
        resource: RestorationStat.values.byName(brush.name),
      ),
      CampaignMarkerBrush.enemy => CampaignEnemySource(
        name,
        point,
        required: false,
        marker: SpawnMarker(
          enemyId: enemy,
          x: point.x,
          chancePercent: 100,
          salt: salt(),
          placement: SpawnPlacementMode.values.byName(
            chunkMarkerDefaultPlacementFor(enemy.name),
          ),
        ),
      ),
      CampaignMarkerBrush.trap => CampaignTrapSource(
        name,
        point.missionChunkId,
        TrapPlacement(
          trapId: trap,
          x: point.x.round(),
          y: point.y.round(),
          trigger: TrapCatalog.get(trap).defaultTrigger,
        ),
      ),
      CampaignMarkerBrush.rescue => CampaignRescueSource(
        name,
        point.missionChunkId,
        EncounterDefinition(
          id: name,
          name: 'Rescue',
          trigger: EncounterTrigger(
            x: point.x,
            y: point.y,
            width: math.min(128, 600 - point.x),
            height: math.min(96, 270 - point.y),
          ),
        ),
        required: false,
      ),
      CampaignMarkerBrush.shrine => attachShrine(name, point),
      _ => null,
    };
    if (placement != null) {
      return CampaignMarkerEntry(
        'placement:${placement.id}',
        placement.position,
        placement: placement,
      );
    }
    if (brush == CampaignMarkerBrush.start) {
      return CampaignMarkerEntry('start', point);
    }
    final region = CampaignRegion(
      origin: point,
      width: math.min(64, 600 - point.x),
      height: math.min(64, 270 - point.y),
    );
    return CampaignMarkerEntry(
      brush == CampaignMarkerBrush.exit
          ? 'exit'
          : 'requiredRegions:${mission.requiredRegions.length}',
      point,
      region: region,
    );
  }

  /// Picks a nearby admitted flat top. The same Core resolver checks both the
  /// preview and captured mission, including prefab transforms and direct shapes.
  CampaignShrineSource attachShrine(
    String id,
    CampaignPoint point, {
    CampaignShrineSource? previous,
  }) {
    final missionChunk = mission.route.firstWhere(
      (o) => o.id == point.missionChunkId,
    );
    final terrain = compiled[missionChunk.chunkKey]?.stagedTerrain;
    if (terrain == null) {
      throw StateError(
        'This mission chunk needs valid compiled terrain before attaching a fire.',
      );
    }
    CampaignShrineSource? result;
    var best = 24.0;
    for (final polygon in terrain.polygons) {
      final lineage = terrain.placementLineage
          .where((p) => p.sourceId == polygon.id)
          .firstOrNull;
      try {
        final binding = WorldInteractionBinding(
          key: id,
          chunkKey: missionChunk.chunkKey,
          prefabKey: lineage?.prefabKey,
          placementKey: polygon.id.placementKey,
          shapeId: polygon.id.shapeId,
          interactionId: WorldInteractionId.regenerationShrine,
          appearanceId: previous?.appearance ?? appearance,
        );
        final surface = resolveWorldInteractionSurface(binding, terrain);
        final left = surface.leftTicks / terrainPhysicsTicksPerWorldUnit;
        final right = surface.rightTicks / terrainPhysicsTicksPerWorldUnit;
        final y = surface.topTicks / terrainPhysicsTicksPerWorldUnit;
        final width = previous?.activationWidth ?? math.min(24.0, right - left);
        if (width > right - left) continue;
        final x = point.x.clamp(left + width / 2, right - width / 2);
        final distance = (x - point.x).abs() + (y - point.y).abs();
        if (distance > best) continue;
        best = distance;
        result = CampaignShrineSource(
          id,
          CampaignPoint(missionChunkId: point.missionChunkId, x: x, y: y),
          prefabKey: lineage?.prefabKey,
          placementKey: polygon.id.placementKey,
          shapeId: polygon.id.shapeId,
          appearance: previous?.appearance ?? appearance,
          activationWidth: width,
          scale: previous?.scale ?? surface.scale,
        );
      } on StateError {
        continue;
      }
    }
    return result ??
        (throw StateError(
          'Point at a flat, collidable shrine or platform top to attach the fire.',
        ));
  }

  CampaignMarkerEntry move(CampaignMarkerEntry entry, CampaignPoint point) {
    final value = entry.placement;
    final placement = value is CampaignShrineSource
        ? attachShrine(value.id, point, previous: value)
        : value == null
        ? null
        : moveCampaignPlacement(value, point);
    final region = entry.region;
    return CampaignMarkerEntry(
      entry.key,
      placement?.position ?? point,
      placement: placement,
      region: region == null
          ? null
          : CampaignRegion(
              origin: point,
              width: region.width,
              height: region.height,
            ),
    );
  }

  String? commit(
    CampaignMarkerEntry? before,
    CampaignMarkerEntry after, {
    CampaignMissionSource? expected,
  }) {
    final captured = expected ?? mission;
    if (captured.id != mission.id || captured.revision != mission.revision) {
      return 'Mission changed during this edit; try again.';
    }
    return apply(
      replaceCampaignMarker(captured, before, after),
      selection: after.key,
    );
  }

  String? apply(Map<String, Object?> json, {String? selection}) {
    try {
      if (session.isLoading ||
          session.isExporting ||
          session.requiresSavedRefresh ||
          session.requiresTransactionRecovery) {
        throw StateError(
          'Finish the current workspace operation before editing.',
        );
      }
      // Fail before command dispatch so invalid pointer/form candidates remain
      // visible with an error and never become history or source state.
      CampaignMissionSource.decode(json);
      session.applyCommand(
        AuthoringCommand(
          kind: CampaignDomainPlugin.replaceMission,
          payload: {
            'id': mission.id,
            'expectedRevision': mission.revision,
            'mission': json,
          },
        ),
      );
      if (selection != null) selectedKey = selection;
      error = null;
    } on Object catch (e) {
      error = '$e';
    }
    notifyListeners();
    return error;
  }

  void delete() {
    if (!finishDraft()) return;
    final entry = selected;
    if (entry == null) return;
    if (entry.placement?.id == mission.blessingObjectiveShrineId &&
        mission.blessingObjectiveShrineId != null) {
      error = 'Reassign or remove the blessing objective before deleting its shrine.';
      notifyListeners();
      return;
    }
    apply(removeCampaignMarker(mission, entry));
    selectedKey = null;
    memberId = null;
    notifyListeners();
  }

  void duplicate() {
    if (!finishDraft()) return;
    final entry = selected;
    if (entry == null || entry.key == 'start' || entry.key == 'exit') return;
    try {
      final p = entry.placement;
      if (p == null) {
        final field = entry.region == null ? 'collectibles' : 'requiredRegions';
        commit(
          null,
          CampaignMarkerEntry(
            '$field:${(mission.toJson()[field] as List).length}',
            entry.position,
            region: entry.region,
          ),
        );
        return;
      }
      final json = p.toJson()..['id'] = id(p.id);
      if (p is CampaignEnemySource) json['salt'] = salt();
      if (p is CampaignRescueSource) {
        (json['encounter'] as Map)['id'] = json['id'];
      }
      final copy = decodeCampaignPlacements([json]).single;
      final point = CampaignPoint(
        missionChunkId: entry.position.missionChunkId,
        x: entry.position.x + (entry.position.x < 560 ? 24 : -24),
        y: entry.position.y,
      );
      final moved = copy is CampaignShrineSource
          ? attachShrine(copy.id, point, previous: copy)
          : moveCampaignPlacement(copy, point);
      commit(
        null,
        CampaignMarkerEntry(
          'placement:${moved.id}',
          moved.position,
          placement: moved,
        ),
      );
    } on Object catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  void addRescueMember({required bool npc}) {
    if (!finishDraft()) return;
    final entry = selected;
    final group = entry?.placement;
    if (entry == null || group is! CampaignRescueSource) return;
    try {
      final name = nextEncounterSourceId(
        npc ? 'npc' : 'enemy',
        [...group.encounter.npcs, ...group.encounter.enemies].map((p) => p.id),
      );
      final x = (group.position.x + group.encounter.trigger.width / 2)
          .roundToDouble();
      final EncounterParticipant member = npc
          ? EncounterNpcPlacement(id: name, npcId: NpcId.warrior, x: x)
          : EncounterEnemyPlacement(id: name, enemyId: enemy, x: x);
      final value = CampaignRescueSource(
        group.id,
        group.missionChunkId,
        addEncounterMember(group.encounter, member),
        required: group.required,
      );
      commit(
        entry,
        CampaignMarkerEntry(entry.key, value.position, placement: value),
      );
      memberId = name;
    } on Object catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  void changeRescueMember(String id, {required bool duplicate}) {
    if (!finishDraft()) return;
    final entry = selected;
    final p = entry?.placement;
    if (entry == null || p is! CampaignRescueSource) return;
    try {
      final source = findEncounterMember(p.encounter, id);
      if (source == null) throw StateError('Select the participant again.');
      final copy = duplicate
          ? duplicateEncounterMember(p.encounter, source)
          : null;
      final group = copy == null
          ? removeEncounterMember(p.encounter, id)
          : addEncounterMember(p.encounter, copy);
      final value = CampaignRescueSource(
        p.id,
        p.missionChunkId,
        group,
        required: p.required,
      );
      if (commit(
            entry,
            CampaignMarkerEntry(entry.key, value.position, placement: value),
          ) ==
          null) {
        memberId = copy?.id;
      }
    } on Object catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    exact.dispose();
    super.dispose();
  }
}
