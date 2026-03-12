library;

import '../snapshots/enums.dart';
import '../util/vec2.dart';
import 'enemy_id.dart';

/// Minimal data captured at the moment an enemy is killed.
///
/// Used to emit render/UI events (e.g. play a death animation) even though the
/// enemy entity is despawned immediately by Core.
class EnemyKilledInfo {
  const EnemyKilledInfo({
    required this.enemyId,
    required this.pos,
    required this.facing,
    required this.artFacingDir,
  });

  final EnemyId enemyId;
  final Vec2 pos;
  final Facing facing;
  final Facing artFacingDir;
}
