import 'package:runner_core/bosses/boss_arena_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';

/// Strict optional Chunk-v2 boss data shared by generation and editor Save/Play.
BossArenaDefinition? decodeBossArena(
  Object? value, {
  required String sourcePath,
  required int chunkWidth,
  required int chunkHeight,
}) {
  if (value is! Map ||
      value.keys.any(
        (k) => !{'id', 'enemyId', 'spawnX', 'minX', 'maxX'}.contains(k),
      ) ||
      value.length != 5 ||
      value['id'] is! String ||
      value['enemyId'] is! String ||
      !['spawnX', 'minX', 'maxX'].every((key) => value[key] is int)) {
    throw FormatException('$sourcePath must be a complete boss arena object.');
  }
  try {
    final arena = BossArenaDefinition(
      id: value['id'] as String,
      enemyId: EnemyId.values.byName(value['enemyId'] as String),
      spawnX: (value['spawnX'] as int).toDouble(),
      minX: (value['minX'] as int).toDouble(),
      maxX: (value['maxX'] as int).toDouble(),
    );
    arena.validateForChunk(chunkWidth, chunkHeight);
    return arena;
  } on ArgumentError catch (error) {
    throw FormatException('$sourcePath: $error');
  }
}

Map<String, Object> bossArenaToJson(BossArenaDefinition arena) => {
  'id': arena.id,
  'enemyId': arena.enemyId.name,
  'spawnX': arena.spawnX.toInt(),
  'minX': arena.minX.toInt(),
  'maxX': arena.maxX.toInt(),
};
