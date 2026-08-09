import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';

/// Pure canonical cell-list mutations shared by legacy and Prefab-v3 routes.
///
/// A `null` result means the requested semantic edit is invalid or a no-op.
/// Accepted lists are ordered by the prefab domain's deterministic grid order.
abstract final class PlatformModuleCellReducer {
  /// Removes one cell by its current canonical-list index.
  static List<TileModuleCellDef>? deleteAt(
    List<TileModuleCellDef> cells,
    int index,
  ) {
    if (index < 0 || index >= cells.length) return null;
    final next = cells.toList(growable: true)..removeAt(index);
    return PrefabDeterminism.sortModuleCellsByGridPosition(next);
  }

  /// Paints or replaces one grid position with [sliceId].
  static List<TileModuleCellDef>? paint(
    List<TileModuleCellDef> cells, {
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    var changed = false;
    var found = false;
    final next = <TileModuleCellDef>[];
    for (final cell in cells) {
      if (cell.gridX == gridX && cell.gridY == gridY) {
        found = true;
        if (cell.sliceId == sliceId) {
          next.add(cell);
        } else {
          changed = true;
          next.add(
            TileModuleCellDef(sliceId: sliceId, gridX: gridX, gridY: gridY),
          );
        }
      } else {
        next.add(cell);
      }
    }
    if (!found) {
      changed = true;
      next.add(TileModuleCellDef(sliceId: sliceId, gridX: gridX, gridY: gridY));
    }
    return changed
        ? PrefabDeterminism.sortModuleCellsByGridPosition(next)
        : null;
  }

  /// Erases the cell occupying one grid position.
  static List<TileModuleCellDef>? erase(
    List<TileModuleCellDef> cells, {
    required int gridX,
    required int gridY,
  }) {
    final next = cells
        .where((cell) => cell.gridX != gridX || cell.gridY != gridY)
        .toList(growable: false);
    return next.length == cells.length
        ? null
        : PrefabDeterminism.sortModuleCellsByGridPosition(next);
  }

  /// Moves one source cell, replacing any cell already at the target.
  static List<TileModuleCellDef>? move(
    List<TileModuleCellDef> cells, {
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    if (sourceGridX == targetGridX && sourceGridY == targetGridY) return null;
    final source = cells
        .where((cell) => cell.gridX == sourceGridX && cell.gridY == sourceGridY)
        .firstOrNull;
    if (source == null) return null;
    final next = cells
        .where(
          (cell) =>
              (cell.gridX != sourceGridX || cell.gridY != sourceGridY) &&
              (cell.gridX != targetGridX || cell.gridY != targetGridY),
        )
        .followedBy(<TileModuleCellDef>[
          TileModuleCellDef(
            sliceId: source.sliceId,
            gridX: targetGridX,
            gridY: targetGridY,
          ),
        ]);
    return PrefabDeterminism.sortModuleCellsByGridPosition(next);
  }
}
