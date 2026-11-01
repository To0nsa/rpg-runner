import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:test/test.dart';

void main() {
  final root = Directory.current.parent.parent.path;
  final sourceText = File('$root/$trainingFieldSourcePath').readAsStringSync();
  final prefabs = File('$root/assets/authoring/level/prefab_defs.json')
      .readAsStringSync();
  final tiles = File('$root/assets/authoring/level/tile_defs.json')
      .readAsStringSync();
  Map<String, dynamic> source() =>
      jsonDecode(sourceText) as Map<String, dynamic>;
  CompiledTrainingField compile(Map<String, dynamic> raw) =>
      compileTrainingField(
        source: TrainingFieldSource.decode(jsonEncode(raw)),
        prefabContents: prefabs,
        tileContents: tiles,
      );

  test('two fixed chunks round-trip without gameplay configuration', () {
    final decoded = TrainingFieldSource.decode(sourceText);
    expect(jsonDecode(decoded.encode()), jsonDecode(sourceText));
    expect(compile(source()).chunks, hasLength(2));
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (raw) => raw['chunks'].removeLast(),
      (raw) => raw['cameraSpeed'] = 0,
      (raw) => raw['chunks'][0]['width'] = 1200,
      (raw) => raw['chunks'][0]['markers'] = [
        {'enemyId': 'derf'},
      ],
      (raw) => raw['enemySpawn']['chunkIndex'] = 2,
    ]) {
      final raw = source();
      mutate(raw);
      expect(
        () => TrainingFieldSource.decode(jsonEncode(raw)),
        throwsFormatException,
      );
    }
  });
  test('each loop seam is validated, including second to first', () {
    for (final vertex in [0, 1]) {
      final raw = source();
      raw['chunks'][1]['collisionShapes'][0]['vertices'][vertex]['y'] = 220;
      expect(() => compile(raw), throwsFormatException);
    }
  });
  test('missing player and enemy support are build errors', () {
    for (final marker in ['playerStart', 'enemySpawn']) {
      final raw = source();
      raw[marker]['y'] = 200;
      expect(() => compile(raw), throwsFormatException);
    }
  });
  test('authored player height is honored beneath an upper platform', () {
    final raw = source();
    raw['chunks'][0]['collisionShapes'].add({
      'shapeId': 'upper_platform',
      'collisionMode': 'solid',
      'surfaceKind': 'platform',
      'materialKey': 'grass_dirt',
      'vertices': [
        {'x': 200, 'y': 100},
        {'x': 400, 'y': 100},
        {'x': 400, 'y': 120},
        {'x': 200, 'y': 120},
      ],
    });
    final core = GameCore.trainingField(
      definition: compile(raw).definition,
      playerCharacter: PlayerCharacterRegistry.eloise,
      equippedLoadout: const EquippedLoadoutDef(),
    );
    expect(core.buildSnapshot().playerEntity!.pos.y, greaterThan(180));
    core.stepOneTick();
    expect(core.buildSnapshot().gameOver, isFalse);
  });
}
