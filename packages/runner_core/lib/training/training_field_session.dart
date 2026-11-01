import '../combat/faction.dart';
import '../ecs/world.dart';
import '../enemies/enemy_id.dart';
import '../track/chunk_pattern.dart';
import '../track/track_streamer.dart';
import 'training_field_definition.dart';

/// Ephemeral one-opponent scheduling. No account progression or replay contract.
final class TrainingFieldSession {
  TrainingFieldSession(this.definition);
  final TrainingFieldDefinition definition;
  EnemyId? selectedEnemy;
  int? _pendingChunk;
  bool _clearRequested = false;

  void selectEnemy(EnemyId? enemy, {required double playerX}) {
    if (enemy?.isArenaOnly ?? false) {
      throw ArgumentError('Training Field supports regular enemies only.');
    }
    selectedEnemy = enemy;
    _clearRequested = enemy == null;
    if (enemy == null) {
      _pendingChunk = null;
      return;
    }
    var next = (playerX / 600).floor() + 1;
    if (next % 2 != definition.enemyChunkIndex) next++;
    _pendingChunk = next;
  }

  void step(
    EcsWorld world, {
    required double cameraRight,
    required List<ActiveTrackChunkSnapshot> chunks,
    required void Function(SpawnEnemyRequest) spawn,
  }) {
    if (_clearRequested) {
      _clearOpponent(world);
      _clearRequested = false;
    }
    final index = _pendingChunk;
    if (index == null ||
        cameraRight < index * 600 ||
        !chunks.any((chunk) => chunk.index == index)) {
      return;
    }
    _clearOpponent(world);
    spawn(
      SpawnEnemyRequest(
        enemyId: selectedEnemy!,
        x: index * 600 + definition.enemySpawnX,
        fallbackSupportY: definition.enemySpawnY,
        placement: SpawnPlacementMode.ground,
        source: EnemySpawnRequestSource.trainingField,
      ),
    );
    _pendingChunk = null;
  }

  void _clearOpponent(EcsWorld world) {
    // Released attacks must not survive a change of opponent, even if their
    // original owner has already died or its entity ID has been recycled.
    for (final entity in world.projectile.denseEntities.toList()) {
      if (world.projectile.faction[world.projectile.indexOf(entity)] ==
          Faction.enemy) {
        world.destroyEntity(entity);
      }
    }
    for (final entity in world.hitbox.denseEntities.toList()) {
      if (world.hitbox.faction[world.hitbox.indexOf(entity)] == Faction.enemy) {
        world.destroyEntity(entity);
      }
    }
    for (final entity in world.enemy.denseEntities.toList()) {
      world.destroyEntity(entity);
    }
  }
}
