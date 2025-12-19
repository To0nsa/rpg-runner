import '../../math/vec2.dart';

class CellAabb {
  const CellAabb({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}

/// Generic 2D grid math + hashing utility.
///
/// This is intentionally reusable for both:
/// - dynamic broadphase buckets (Milestone 9), and
/// - future nav/cost grids (later milestone).
///
/// IMPORTANT (determinism):
/// - `cellKey(cx, cy)` must be stable and must not use Dart `hashCode`.
class GridIndex2D {
  GridIndex2D({required this.cellSize}) : invCellSize = 1.0 / cellSize;

  final double cellSize;
  final double invCellSize;

  int worldToCellX(double x) => (x * invCellSize).floor();
  int worldToCellY(double y) => (y * invCellSize).floor();

  Vec2 cellToWorldMin(int cx, int cy) => Vec2(cx * cellSize, cy * cellSize);

  CellAabb cellAabb(int cx, int cy) {
    final minX = cx * cellSize;
    final minY = cy * cellSize;
    return CellAabb(
      minX: minX,
      minY: minY,
      maxX: minX + cellSize,
      maxY: minY + cellSize,
    );
  }

  /// Packs signed (cx, cy) into a single int key (two 32-bit lanes).
  int cellKey(int cx, int cy) {
    final ux = (cx ^ 0x80000000) & 0xFFFFFFFF;
    final uy = (cy ^ 0x80000000) & 0xFFFFFFFF;
    return (uy << 32) | ux;
  }

  void forNeighbors(
    int cx,
    int cy, {
    bool diagonal = false,
    required void Function(int nx, int ny) visit,
  }) {
    // Stable order (N, W, E, S), then diagonals (NW, NE, SW, SE).
    visit(cx, cy - 1);
    visit(cx - 1, cy);
    visit(cx + 1, cy);
    visit(cx, cy + 1);

    if (!diagonal) return;
    visit(cx - 1, cy - 1);
    visit(cx + 1, cy - 1);
    visit(cx - 1, cy + 1);
    visit(cx + 1, cy + 1);
  }
}

