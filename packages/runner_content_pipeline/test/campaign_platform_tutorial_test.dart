import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final root = Directory.current.parent.parent.path;
  const path =
      'assets/authoring/level/chunks/forest/forest_default_early_cmp_005.json';
  const key = 'tiny_swords_ground_platform_04_64x32_platform';
  final source = File('$root/$path').readAsStringSync();
  final prefabSource = File('$root/assets/authoring/level/prefab_defs.json')
      .readAsStringSync();
  final tiles = File('$root/assets/authoring/level/tile_defs.json')
      .readAsStringSync();
  PolygonTerrainRuntimeChunk compile(
    Map<String, dynamic> json, {
    String? prefabs,
  }) {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: prefabs ?? prefabSource,
      tileSourcePath: 'assets/authoring/level/tile_defs.json',
      tileContents: tiles,
      chunkSourcePath: path,
      chunkContents: jsonEncode(json),
    );
    expect(
      result.issues,
      isEmpty,
      reason: result.issues.map((i) => i.message).join('\n'),
    );
    return result.chunk!;
  }

  List<CampaignTutorialPlatform> targets(PolygonTerrainRuntimeChunk chunk) =>
      campaignTutorialPlatforms(
        chunk.stagedTerrain,
        chunk.pattern.visualSprites,
      );
  final lesson = CampaignPlatformTutorial.introduction(
    missionChunkId: 'fourth',
    platformPrefabKey: key,
  );
  test(
    'platform contract is strict, bilingual and reveals no additional HUD',
    () {
      expect(decodeCampaignTutorial(lesson.toJson()).toJson(), lesson.toJson());
      expect(lesson.reveals, isEmpty);
      expect(lesson.target.isWorld, isTrue);
      expect(lesson.continuationAt(0), CampaignTutorialContinuation.movement);
      for (final field in [
        'missionChunkId',
        'platformPrefabKey',
        'approachDistance',
        'instruction',
        'spotlight',
      ]) {
        expect(
          () => decodeCampaignTutorial(lesson.toJson()..[field] = null),
          throwsFormatException,
        );
      }
      for (final distance in [0, 601, double.nan]) {
        expect(
          () => decodeCampaignTutorial(
            lesson.toJson()..['approachDistance'] = distance,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => decodeCampaignTutorial(lesson.toJson()..['extra'] = 1),
        throwsFormatException,
      );
      expect(
        () => decodeCampaignTutorial(
          lesson.toJson()..['instruction'] = {'en': 'English only'},
        ),
        throwsFormatException,
      );
      expect(
        () => decodeCampaignTutorials([lesson.toJson(), lesson.toJson()]),
        throwsFormatException,
      );
    },
  );
  test('tiled platform selection follows moves, resizing and reorder', () {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final original = compile(json);
    final visuals = original.pattern.visualSprites;
    // Several render pieces for one collision placement remain a single target.
    expect(
      campaignTutorialPlatforms(original.stagedTerrain, [
        ...visuals,
        visuals.firstWhere((s) => s.prefabKey == key),
      ]).where((p) => p.prefabKey == key),
      hasLength(1),
    );
    final before = targets(original).first;
    expect(before.prefabKey, key);
    expect(before.bounds, (x: 160.0, y: 160.0, width: 64.0, height: 32.0));
    expect((before.left, before.right), (160, 222));
    final placement = (json['prefabs'] as List).firstWhere(
      (p) => p['prefabKey'] == key,
    );
    placement['x'] = 210;
    placement['y'] = 180;
    placement['scale'] = 1.5;
    placement['snapToGrid'] = false;
    (json['prefabs'] as List).remove(placement);
    placement['zIndex'] = 1;
    (json['prefabs'] as List).add(placement);
    final after = targets(compile(json))
        .where((p) => p.prefabKey == key)
        .single;
    expect(after.bounds, (x: 162.0, y: 156.0, width: 96.0, height: 48.0));
    expect((after.left, after.right), (162, 255));
  });
  for (final invalid in ['missing', 'duplicate', 'solid']) {
    test('platform refuses $invalid target', () {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final placements = json['prefabs'] as List;
      final placement = placements.firstWhere((p) => p['prefabKey'] == key);
      String? prefabs;
      switch (invalid) {
        case 'missing':
          placements.remove(placement);
        case 'duplicate':
          placements.insert(placements.indexOf(placement) + 1, {
            ...placement,
            'x': 544,
          });
        case 'solid':
          final data = jsonDecode(prefabSource);
          final prefab = (data['prefabs'] as List).firstWhere(
            (p) => p['prefabKey'] == key,
          );
          prefab['kind'] = 'obstacle';
          for (final shape in prefab['collisionShapes'] as List) {
            shape['collisionMode'] = 'solid';
          }
          prefabs = jsonEncode(data);
      }
      final chunk = compile(json, prefabs: prefabs);
      expect(targets(chunk).where((p) => p.prefabKey == key), isEmpty);
      expect(
        targets(chunk).any((p) => p.prefabKey == 'pixel_fantasy_caves_bush_01'),
        isFalse,
      );
    });
  }
}
