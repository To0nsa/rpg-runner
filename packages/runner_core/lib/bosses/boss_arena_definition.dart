import '../contracts/spatial_contract.dart';
import '../enemies/enemy_id.dart';

/// One mandatory, viewport-sized fight; all coordinates are chunk-local units.
/// Enemy timing and rewards remain catalog-owned, independent of placement.
final class BossArenaDefinition {
  BossArenaDefinition({
    required this.id,
    required this.enemyId,
    required this.spawnX,
    required this.minX,
    required this.maxX,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id) ||
        !enemyId.isBoss ||
        ![spawnX, minX, maxX].every((v) => v.isFinite) ||
        ![spawnX, minX, maxX].every((v) => v == v.roundToDouble()) ||
        minX < 0 ||
        maxX > virtualViewportWidth ||
        minX >= maxX ||
        spawnX <= minX ||
        spawnX >= maxX) {
      throw ArgumentError('Invalid boss arena identity, boss or bounds.');
    }
  }
  final String id;
  final EnemyId enemyId;
  final double spawnX;
  final double minX;
  final double maxX;

  @override
  bool operator ==(Object other) =>
      other is BossArenaDefinition &&
      id == other.id &&
      enemyId == other.enemyId &&
      spawnX == other.spawnX &&
      minX == other.minX &&
      maxX == other.maxX;
  @override
  int get hashCode => Object.hash(id, enemyId, spawnX, minX, maxX);

  /// Admission requires the complete arena to fit the fixed gameplay viewport.
  void validateForChunk(num width, num height) {
    if (width != virtualViewportWidth || height != virtualViewportHeight) {
      throw ArgumentError('Boss arenas must match the 600x270 viewport.');
    }
  }
}
