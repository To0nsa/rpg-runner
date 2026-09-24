import 'dart:ui';

import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import '../../../../chunks/chunk_encounter_edit.dart';
import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_composition_commit.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../shared/scene_rectangle_gesture.dart';
import 'chunk_scene_snap_vertices.dart';
import 'chunk_encounter_projection.dart';

enum ChunkEncounterTool {
  select,
  placeNpc,
  placeEnemy,
  moveTrigger,
  drawTrigger,
}

typedef ChunkEncounterGestureResult = ({
  ChunkV2CompositionCommit? commit,
  ChunkEncounterSelection selection,
  String? error,
});

/// Local preview around shared snapping/rectangle gestures. Release emits one
/// revision-guarded command; Escape leaves document history untouched.
final class ChunkEncounterGesture {
  ChunkEncounterTool tool = ChunkEncounterTool.select;
  NpcId npcId = NpcId.warrior;
  EnemyId enemyId = EnemyId.hashash;
  Facing facing = Facing.right;
  SpawnPlacementMode placement = SpawnPlacementMode.ground;
  int? _pointer;
  ChunkV2FileData? _chunk;
  EncounterDefinition? _original;
  EncounterParticipant? _member;
  ChunkEncounterSelection? selection;
  ChunkV2CompositionOperation? _operation;
  SceneRectangleGesture? _rectangle;
  Offset? _start;
  int _step = 1;
  List<double> _neighborXs = const [];
  double _zoom = 1;
  EncounterDefinition? candidate;
  String? error;
  bool get hasActiveOperation => _pointer != null;

  bool begin({
    required ChunkV2FileData chunk,
    required ChunkEncounterSelection selected,
    required int pointer,
    required Offset point,
    required double zoom,
    required bool snapToGrid,
    required bool snapToNeighbors,
    ChunkV2CollisionExpansion? expansion,
  }) {
    if (hasActiveOperation) return false;
    final group = findChunkEncounter(chunk.encounters, selected.encounterId);
    if (group == null) return false;
    _step = snapToGrid ? chunk.tileSize : 1;
    _zoom = zoom;
    final neighbors = chunkWholePixelSnapVertices(
      chunk: chunk,
      expansion: expansion,
    );
    _neighborXs = snapToNeighbors
        ? neighbors
              .map((v) => v.xHalfPixels * .5)
              .where((x) => x < chunk.width)
              .toSet()
              .toList()
        : const [];
    _chunk = chunk;
    _original = group;
    selection = selected;
    _start = point;
    _operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.encounters,
      sourceIndex: chunk.encounters.indexOf(group),
    );
    final adding =
        tool == ChunkEncounterTool.placeNpc ||
        tool == ChunkEncounterTool.placeEnemy;
    if (adding) {
      final id = nextEncounterSourceId(
        tool == ChunkEncounterTool.placeNpc ? npcId.name : 'enemy',
        [...group.npcs, ...group.enemies].map((e) => e.id),
      );
      _member = tool == ChunkEncounterTool.placeNpc
          ? EncounterNpcPlacement(
              id: id,
              npcId: npcId,
              x: _x(point.dx),
              facing: facing,
              placement: placement,
            )
          : EncounterEnemyPlacement(
              id: id,
              enemyId: enemyId,
              x: _x(point.dx),
              facing: facing,
              placement: placement,
            );
      selection = ChunkEncounterSelection(group.id, memberId: id);
    } else if (tool == ChunkEncounterTool.select && selected.memberId != null) {
      _member = findEncounterMember(group, selected.memberId!);
      if (_member == null) {
        cancel();
        return false;
      }
    } else {
      final bounds = encounterTriggerBounds(group);
      final corner = tool == ChunkEncounterTool.select
          ? hitTestSceneRectangleCorner(
              bounds: bounds,
              worldPoint: point,
              zoom: zoom,
            )
          : null;
      final drawing = tool == ChunkEncounterTool.drawTrigger;
      _rectangle = SceneRectangleGesture(
        pointer: pointer,
        worldPoint: point,
        limit: Size(chunk.width.toDouble(), chunk.height.toDouble()),
        snapPolicy: TerrainPolygonSnapPolicy.ownerGridPixels(_step),
        neighbors: neighbors,
        snapToNeighbors: snapToNeighbors,
        zoom: zoom,
        original: drawing ? null : bounds,
        corner: corner,
        moving: !drawing && corner == null,
      );
      selection = ChunkEncounterSelection(group.id);
    }
    _pointer = pointer;
    update(pointer: pointer, point: point, zoom: zoom);
    return true;
  }

  double _x(double value) {
    double? nearest;
    var distance = 8 / _zoom;
    for (final x in _neighborXs) {
      final delta = (x - value).abs();
      if (delta <= distance && (nearest == null || delta < distance)) {
        nearest = x;
        distance = delta;
      }
    }
    return nearest ??
        quantizeChunkSceneCoordinate(
          value,
          step: _step,
        ).clamp(0, _chunk!.width - 1).toDouble();
  }

  void update({
    required int pointer,
    required Offset point,
    required double zoom,
  }) {
    if (pointer != _pointer) return;
    _zoom = zoom;
    error = null;
    try {
      if (_rectangle != null) {
        _rectangle!.update(pointer: pointer, worldPoint: point, zoom: zoom);
        final r = _rectangle!.bounds;
        candidate = editEncounter(
          _original!,
          trigger: EncounterTrigger(
            x: r.left,
            y: r.top,
            width: r.width,
            height: r.height,
          ),
        );
      } else {
        final adding =
            tool == ChunkEncounterTool.placeNpc ||
            tool == ChunkEncounterTool.placeEnemy;
        final x = !adding && (point.dx - _start!.dx).abs() < 1e-8
            ? _member!.x
            : _x(adding ? point.dx : _member!.x + point.dx - _start!.dx);
        final member = switch (_member!) {
          EncounterNpcPlacement m => editEncounterNpc(m, x: x),
          EncounterEnemyPlacement m => editEncounterEnemy(m, x: x),
        };
        candidate = adding
            ? addEncounterMember(_original!, member)
            : replaceEncounterMember(_original!, member);
      }
      candidate!.validateForChunk(
        _chunk!.width.toDouble(),
        requireComplete: false,
      );
    } on ArgumentError catch (e) {
      error = e.message.toString();
    }
  }

  ChunkEncounterGestureResult? finish({
    required int pointer,
    required Offset point,
    required double zoom,
  }) {
    if (pointer != _pointer) return null;
    update(pointer: pointer, point: point, zoom: zoom);
    final result = (
      commit: error == null
          ? _operation!.buildEncounter(candidate: candidate)
          : null,
      selection: selection!,
      error: error,
    );
    cancel();
    return result;
  }

  bool cancel() {
    final active = hasActiveOperation;
    _pointer = null;
    _chunk = null;
    _original = null;
    _member = null;
    _neighborXs = const [];
    _rectangle = null;
    _operation = null;
    candidate = null;
    selection = null;
    error = null;
    return active;
  }
}
