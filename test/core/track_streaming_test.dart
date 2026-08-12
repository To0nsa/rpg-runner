import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../support/test_player.dart';

void _expectStagedTerrainEqual(GameCore a, GameCore b) {
  final left = a.buildSnapshot().stagedTerrainRenderSnapshot;
  final right = b.buildSnapshot().stagedTerrainRenderSnapshot;
  expect(left, isNotNull);
  expect(right, isNotNull);
  expect(right!.geometryVersion, left!.geometryVersion);
  expect(right.polygons.length, left.polygons.length);
  expect(right.edges.length, left.edges.length);
  for (var index = 0; index < left.polygons.length; index += 1) {
    final expected = left.polygons[index];
    final actual = right.polygons[index];
    expect(actual.sourceId, expected.sourceId);
    expect(actual.vertices, expected.vertices);
    expect(actual.triangles.length, expected.triangles.length);
    for (
      var triangleIndex = 0;
      triangleIndex < expected.triangles.length;
      triangleIndex += 1
    ) {
      final expectedTriangle = expected.triangles[triangleIndex];
      final actualTriangle = actual.triangles[triangleIndex];
      expect(actualTriangle.first, expectedTriangle.first);
      expect(actualTriangle.second, expectedTriangle.second);
      expect(actualTriangle.third, expectedTriangle.third);
    }
    expect(actual.materialKey, expected.materialKey);
  }
}

void main() {
  test('track streaming is deterministic and stays bounded (culling)', () {
    const seed = 12345;
    // Disable right-side wall collision so the player never gets stuck on a
    // chunk obstacle and can run long enough to exercise spawn/cull.
    //
    // Also disable gravity so this test isolates deterministic streaming and
    // culling from actor locomotion.
    final base = PlayerCharacterRegistry.eloise;
    final playerCharacter = base.copyWith(
      catalog: testPlayerCatalog(
        bodyTemplate: BodyDef(sideMask: BodyDef.sideLeft, useGravity: false),
      ),
    );
    final level = LevelRegistry.byId(
      LevelId.field,
    ).copyWith(noEnemyChunks: 9999);
    final a = GameCore(
      levelDefinition: level,
      seed: seed,
      playerCharacter: playerCharacter,
    );
    final b = GameCore(
      levelDefinition: level,
      seed: seed,
      playerCharacter: playerCharacter,
    );
    _expectStagedTerrainEqual(a, b);
    expect(a.buildSnapshot().stagedTerrainRenderSnapshot!.polygons, isNotEmpty);
    final initialChunkIndices = a
        .buildSnapshot()
        .stagedTerrainRenderSnapshot!
        .polygons
        .map((polygon) => polygon.sourceId.chunkIndex)
        .toSet();

    // Always move right so the player stays in view and the camera keeps advancing.
    const ticks =
        1800; // ~30 seconds at 60Hz (enough to trigger multiple spawn/cull cycles).
    var maxTerrainPolygons = 0;

    for (var t = 1; t <= ticks; t += 1) {
      final cmds = <Command>[MoveAxisCommand(tick: t, axis: 1.0)];
      a.applyCommands(cmds);
      b.applyCommands(cmds);
      a.stepOneTick();
      b.stepOneTick();

      if (t % 20 == 0) {
        _expectStagedTerrainEqual(a, b);
      }

      final polygons = a
          .buildSnapshot()
          .stagedTerrainRenderSnapshot!
          .polygons
          .length;
      if (polygons > maxTerrainPolygons) maxTerrainPolygons = polygons;

      expect(a.gameOver, isFalse);
      expect(b.gameOver, isFalse);
    }

    // Culling keeps the streamed world bounded (does not grow without limit).
    // This threshold is intentionally loose; it only exists to catch “no cull” regressions.
    expect(maxTerrainPolygons, lessThan(120));
    final finalTerrain = a.buildSnapshot().stagedTerrainRenderSnapshot!;
    final finalChunkIndices = finalTerrain.polygons
        .map((polygon) => polygon.sourceId.chunkIndex)
        .toSet();
    expect(finalChunkIndices.intersection(initialChunkIndices), isEmpty);
    expect(
      finalTerrain.polygons.map((polygon) => polygon.sourceId.chunkKey),
      everyElement('field_flat'),
    );
    expect(
      finalTerrain.polygons.map((polygon) => polygon.sourceId.shapeId),
      everyElement('ground_001'),
    );
  });
}
