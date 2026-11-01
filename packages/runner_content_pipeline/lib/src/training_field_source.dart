import 'dart:convert';

import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:runner_core/training/training_field_definition.dart';
import 'package:runner_core/training/training_field_placement.dart';

import 'chunk_runtime_materialization.dart';
import 'polygon_terrain_render.dart';
import 'polygon_terrain_seam_manifest.dart';
import 'polygon_terrain_seam_validation.dart';

const trainingFieldSourcePath = 'assets/authoring/level/training_field.json';

/// Separate source envelope reusing strict chunk-v2 geometry. It deliberately
/// has no pacing, enemy roster, reward, or gameplay-mode settings.
final class TrainingFieldSource {
  TrainingFieldSource._(
    this.revision,
    this.visualThemeId,
    this.playerStartX,
    this.playerStartY,
    this.enemyChunkIndex,
    this.enemySpawnX,
    this.enemySpawnY,
    this.chunkContents,
  );

  factory TrainingFieldSource.decode(String contents) {
    final raw = jsonDecode(contents);
    if (raw is! Map<String, dynamic> ||
        raw['schemaVersion'] != 1 ||
        raw.keys.toSet().difference({
          'schemaVersion',
          'revision',
          'visualThemeId',
          'playerStart',
          'enemySpawn',
          'chunks',
        }).isNotEmpty) {
      throw const FormatException('Invalid Training Field schema.');
    }
    int integer(Object? value, String name) {
      if (value is! int) {
        throw FormatException('$name must be a whole pixel/integer.');
      }
      return value;
    }

    final revision = integer(raw['revision'], 'revision');
    final theme = raw['visualThemeId'];
    final player = raw['playerStart'];
    final enemy = raw['enemySpawn'];
    final chunks = raw['chunks'];
    if (revision < 1 ||
        theme is! String ||
        theme.isEmpty ||
        player is! Map ||
        enemy is! Map ||
        chunks is! List ||
        chunks.length != 2 ||
        player.length != 2 ||
        enemy.length != 3) {
      throw const FormatException(
        'Training Field needs two chunks and two spawn positions.',
      );
    }
    final px = integer(player['x'], 'playerStart.x');
    final py = integer(player['y'], 'playerStart.y');
    final ec = integer(enemy['chunkIndex'], 'enemySpawn.chunkIndex');
    final ex = integer(enemy['x'], 'enemySpawn.x');
    final ey = integer(enemy['y'], 'enemySpawn.y');
    if (px <= 0 ||
        px >= 600 ||
        py < 0 ||
        py > 270 ||
        ex <= 0 ||
        ex >= 600 ||
        ey < 0 ||
        ey > 270 ||
        ec < 0 ||
        ec > 1) {
      throw const FormatException(
        'Spawn positions must be inside their chunks.',
      );
    }
    for (var i = 0; i < 2; i++) {
      final chunk = chunks[i];
      if (chunk is! Map ||
          chunk['chunkKey'] != 'training_field_${i + 1}' ||
          chunk['id'] != 'training_field_${i + 1}' ||
          chunk['levelId'] != 'training_field' ||
          chunk['width'] != 600 ||
          chunk['height'] != 270 ||
          chunk['status'] != 'active' ||
          chunk['difficulty'] != 'easy' ||
          chunk['assemblyGroupId'] != 'default' ||
          chunk['bossArena'] != null ||
          ['markers', 'traps', 'encounters', 'waterRegions'].any(
            (key) =>
                chunk[key] != null &&
                (chunk[key] is! List || (chunk[key] as List).isNotEmpty),
          )) {
        throw FormatException(
          'Chunk ${i + 1} must contain only Training Field layout data.',
        );
      }
    }
    return TrainingFieldSource._(
      revision,
      theme,
      px,
      py,
      ec,
      ex,
      ey,
      List.unmodifiable(chunks.map(jsonEncode)),
    );
  }

  final int revision;
  final String visualThemeId;
  final int playerStartX,
      playerStartY,
      enemyChunkIndex,
      enemySpawnX,
      enemySpawnY;
  final List<String> chunkContents;

  String encode({
    int? revision,
    List<String>? chunks,
    int? playerX,
    int? playerY,
    int? enemyChunk,
    int? enemyX,
    int? enemyY,
  }) =>
      '${const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'revision': revision ?? this.revision,
        'visualThemeId': visualThemeId,
        'playerStart': {'x': playerX ?? playerStartX, 'y': playerY ?? playerStartY},
        'enemySpawn': {'chunkIndex': enemyChunk ?? enemyChunkIndex, 'x': enemyX ?? enemySpawnX, 'y': enemyY ?? enemySpawnY},
        'chunks': (chunks ?? chunkContents).map(jsonDecode).toList(),
      })}\n';
}

final class CompiledTrainingField {
  const CompiledTrainingField(this.source, this.chunks, this.batch);
  final TrainingFieldSource source;
  final List<PolygonTerrainRuntimeChunk> chunks;
  final PolygonTerrainValidatedBatch batch;

  TrainingFieldDefinition get definition => TrainingFieldDefinition(
    chunks: chunks.map((c) => c.pattern),
    terrain: materializeStagedTerrainArtifact(batch),
    playerStartX: source.playerStartX.toDouble(),
    playerStartY: source.playerStartY.toDouble(),
    enemyChunkIndex: source.enemyChunkIndex,
    enemySpawnX: source.enemySpawnX.toDouble(),
    enemySpawnY: source.enemySpawnY.toDouble(),
    visualThemeId: source.visualThemeId,
  );
}

CompiledTrainingField compileTrainingField({
  required TrainingFieldSource source,
  required String prefabContents,
  required String tileContents,
}) {
  final chunks = <PolygonTerrainRuntimeChunk>[];
  for (var i = 0; i < 2; i++) {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: prefabContents,
      tileSourcePath: 'assets/authoring/level/tile_defs.json',
      tileContents: tileContents,
      chunkSourcePath: '$trainingFieldSourcePath/chunks/$i',
      chunkContents: source.chunkContents[i],
      groundTopY: source.playerStartY.toDouble(),
    );
    if (result.chunk == null || result.issues.isNotEmpty) {
      throw FormatException(
        result.issues.map((e) => '${e.code}: ${e.message}').join('\n'),
      );
    }
    chunks.add(result.chunk!);
  }
  final seams = validatePolygonTerrainSeams(
    chunks: chunks.map((c) => c.compiled),
    manifest: PolygonTerrainSeamManifest(
      sourcePath: trainingFieldSourcePath,
      signature: TerrainAuthoringSeamSignature([
        for (var i = 0; i < 2; i++)
          TerrainAuthoringSeamTransition(
            levelId: 'training_field',
            transitionId: 'loop_$i',
            leftChunkKey: chunks[i].pattern.chunkKey!,
            rightChunkKey: chunks[1 - i].pattern.chunkKey!,
          ),
      ]),
    ),
  );
  if (seams.batch == null) {
    throw FormatException(seams.issues.map((e) => e.message).join('\n'));
  }
  final field = CompiledTrainingField(
    source,
    List.unmodifiable(chunks),
    seams.batch!,
  );
  try {
    validateTrainingFieldPlacement(field.definition);
  } on ArgumentError catch (error) {
    throw FormatException('Training Field: ${error.message}');
  }
  return field;
}
