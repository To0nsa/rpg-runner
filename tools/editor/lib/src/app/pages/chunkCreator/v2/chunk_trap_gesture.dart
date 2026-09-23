import 'dart:ui';

import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/traps/trap_validation.dart';

import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_composition_commit.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../shared/scene_rectangle_gesture.dart';
import 'chunk_scene_snap_vertices.dart';

enum ChunkTrapTool { select, place, moveTrigger, drawTrigger }

Rect trapTriggerBounds(TrapPlacement trap) => Rect.fromLTWH(
  (trap.x + trap.trigger.offsetX).toDouble(),
  (trap.y + trap.trigger.offsetY).toDouble(),
  trap.trigger.width.toDouble(),
  trap.trigger.height.toDouble(),
);

Rect trapSpriteBounds(TrapPlacement trap) {
  final source = TrapCatalog.get(trap.trapId).spriteBounds;
  final bounds = trap.facing == Facing.left ? source.mirrored() : source;
  return Rect.fromLTWH(
    (trap.x + bounds.offsetX).toDouble(),
    (trap.y + bounds.offsetY).toDouble(),
    bounds.width.toDouble(),
    bounds.height.toDouble(),
  );
}

TrapPlacement? hitTestChunkTrap(
  List<TrapPlacement> traps,
  Offset point, {
  bool trigger = false,
}) => traps.reversed
    .where(
      (trap) => (trigger ? trapTriggerBounds(trap) : trapSpriteBounds(trap))
          .contains(point),
    )
    .firstOrNull;

String? validateChunkTrapCandidate(
  ChunkV2FileData chunk,
  TrapPlacement candidate, {
  TrapPlacement? replacing,
}) {
  try {
    final traps = [
      for (final trap in chunk.traps)
        if (trap != replacing) trap,
      candidate,
    ]..sort(compareTrapPlacements);
    validateTrapPlacements(
      traps,
      chunkWidth: chunk.width,
      chunkHeight: chunk.height,
    );
    return null;
  } on ArgumentError catch (error) {
    return error.message.toString();
  }
}

typedef ChunkTrapGestureResult = ({
  TrapPlacement candidate,
  ChunkV2CompositionCommit? commit,
  String? error,
});

/// Trap policy around shared rectangle gestures. Only a finished valid candidate
/// becomes a revision-checked composition command; drag previews stay local.
final class ChunkTrapGesture {
  ChunkTrapTool tool = ChunkTrapTool.select;
  TrapId catalogId = TrapId.spike;
  int previewFrame = 0;
  ChunkV2FileData? _chunk;
  ChunkV2CompositionOperation? _operation;
  SceneRectangleGesture? _gesture;
  TrapPlacement? _original;
  Rect? _originalBounds;
  bool _editingTrigger = false;
  TrapPlacement? candidate;
  String? error;
  bool get hasActiveOperation => _gesture != null;
  int? get hiddenSourceIndex => _operation?.sourceIndex;
  Offset? get snappedNeighbor => _gesture?.snappedNeighbor;

  bool begin({
    required ChunkV2FileData chunk,
    required int pointer,
    required Offset point,
    required TrapPlacement? selected,
    required double zoom,
    required bool snapToGrid,
    required bool snapToNeighbors,
    ChunkV2CollisionExpansion? expansion,
  }) {
    if (hasActiveOperation) return false;
    final adding = tool == ChunkTrapTool.place;
    if (!adding && selected == null) return false;
    final step = snapToGrid ? chunk.tileSize : 1;
    final trap = adding
        ? TrapPlacement(
            trapId: catalogId,
            x: quantizeChunkSceneCoordinate(point.dx, step: step),
            y: quantizeChunkSceneCoordinate(point.dy, step: step),
            trigger: TrapCatalog.get(catalogId).defaultTrigger,
          )
        : selected!;
    final corner = !adding && tool == ChunkTrapTool.select
        ? hitTestSceneRectangleCorner(
            bounds: trapTriggerBounds(trap),
            worldPoint: point,
            zoom: zoom,
          )
        : null;
    _editingTrigger =
        tool == ChunkTrapTool.moveTrigger ||
        tool == ChunkTrapTool.drawTrigger ||
        corner != null;
    final drawing = tool == ChunkTrapTool.drawTrigger;
    final bounds = _editingTrigger
        ? trapTriggerBounds(trap)
        : trapSpriteBounds(trap).expandToInclude(trapTriggerBounds(trap));
    if (bounds.width > chunk.width || bounds.height > chunk.height) {
      error = 'This trap and trigger do not fit inside the chunk.';
      return false;
    }
    _chunk = chunk;
    _original = trap;
    _originalBounds = bounds;
    _operation = adding
        ? ChunkV2CompositionOperation.add(
            chunk: chunk,
            target: ChunkV2CompositionTarget.traps,
          )
        : ChunkV2CompositionOperation.replace(
            chunk: chunk,
            target: ChunkV2CompositionTarget.traps,
            sourceIndex: chunk.traps.indexOf(trap),
          );
    _gesture = SceneRectangleGesture(
      pointer: pointer,
      worldPoint: point,
      limit: Size(chunk.width.toDouble(), chunk.height.toDouble()),
      snapPolicy: TerrainPolygonSnapPolicy.ownerGridPixels(step),
      neighbors: chunkWholePixelSnapVertices(
        chunk: chunk,
        expansion: expansion,
        excludingTrap: selected,
      ),
      snapToNeighbors: snapToNeighbors,
      zoom: zoom,
      original: drawing ? null : bounds,
      corner: corner,
      moving: !drawing && corner == null,
    );
    _refresh();
    return true;
  }

  void update({
    required int pointer,
    required Offset point,
    required double zoom,
  }) {
    _gesture?.update(pointer: pointer, worldPoint: point, zoom: zoom);
    if (_gesture != null) _refresh();
  }

  ChunkTrapGestureResult? finish({
    required int pointer,
    required Offset point,
    required double zoom,
  }) {
    final gesture = _gesture;
    if (gesture == null) return null;
    gesture.finish(pointer: pointer, worldPoint: point, zoom: zoom);
    if (gesture.isDragging) return null;
    _refresh();
    final result = (
      candidate: candidate!,
      error: error,
      commit: error == null
          ? _operation!.buildTrap(candidate: candidate)
          : null,
    );
    cancel();
    return result;
  }

  bool cancel() {
    final active = hasActiveOperation;
    _gesture = null;
    _operation = null;
    _chunk = null;
    _original = null;
    _originalBounds = null;
    candidate = null;
    error = null;
    return active;
  }

  void _refresh() {
    final bounds = _gesture!.bounds;
    final original = _original!;
    candidate = _editingTrigger
        ? original.copyWith(
            trigger: TrapRect(
              bounds.left.round() - original.x,
              bounds.top.round() - original.y,
              bounds.width.round(),
              bounds.height.round(),
            ),
          )
        : original.copyWith(
            x: original.x + (bounds.left - _originalBounds!.left).round(),
            y: original.y + (bounds.top - _originalBounds!.top).round(),
          );
    error = validateChunkTrapCandidate(
      _chunk!,
      candidate!,
      replacing: _operation!.sourceIndex == null ? null : original,
    );
  }
}
