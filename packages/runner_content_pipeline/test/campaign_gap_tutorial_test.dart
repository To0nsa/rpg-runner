import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final root = Directory.current.parent.parent.path;
  const path =
      'assets/authoring/level/chunks/forest/forest_default_early_cmp_004.json';
  final source = File('$root/$path').readAsStringSync();
  final prefabs = File('$root/assets/authoring/level/prefab_defs.json')
      .readAsStringSync();
  final tiles = File('$root/assets/authoring/level/tile_defs.json')
      .readAsStringSync();
  List<CampaignTutorialGap> gaps(Map<String, dynamic> json) {
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: prefabs,
      tileSourcePath: 'assets/authoring/level/tile_defs.json',
      tileContents: tiles,
      chunkSourcePath: path,
      chunkContents: jsonEncode(json),
    );
    expect(result.issues, isEmpty);
    return campaignTutorialGaps(result.chunk!.stagedTerrain);
  }

  final lesson = CampaignGapTutorial.introduction(
    missionChunkId: 'third',
    nearGroundShapeId: 'ground_001',
    farGroundShapeId: 'solid_002',
  );
  test('strict bilingual gap contract uses movement and no new HUD', () {
    expect(decodeCampaignTutorial(lesson.toJson()).toJson(), lesson.toJson());
    expect(lesson.reveals, isEmpty);
    expect(lesson.optional, isFalse);
    expect(lesson.target.isWorld, isTrue);
    expect(lesson.continuationAt(0), CampaignTutorialContinuation.movement);
    for (final field in [
      'missionChunkId',
      'nearGroundShapeId',
      'farGroundShapeId',
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
      () => decodeCampaignTutorial(lesson.toJson()..['unexpected'] = 1),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorial(
        lesson.toJson()..['farGroundShapeId'] = 'ground_001',
      ),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorial(
        lesson.toJson()..['instruction'] = {'en': 'Only English'},
      ),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorials([lesson.toJson(), lesson.toJson()]),
      throwsFormatException,
    );
  });
  test(
    'real gap uses solid banks and follows changed geometry, not pit art',
    () {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final before = gaps(json).single;
      expect((before.x, before.y, before.width), (221, 224, 69));
      expect(before.bounds, (x: 221.0, y: 200.0, width: 69.0, height: 72.0));
      final shapes = json['collisionShapes'] as List;
      // Move both vertices of the near ledge; the visual-only pit remains unchanged.
      for (final v in shapes.first['vertices'] as List) {
        if (v['x'] == 221) v['x'] = 201;
      }
      final after = gaps(json).single;
      expect(after.nearGroundShapeId, before.nearGroundShapeId);
      expect((after.x, after.width), (201, 89));
    },
  );
  for (final invalid in ['water', 'filled', 'uneven', 'oneWay', 'missing']) {
    test('target candidates reject $invalid gap', () {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final shapes = json['collisionShapes'] as List;
      switch (invalid) {
        case 'water':
          json['waterRegions'] = [
            {
              'id': 'pool',
              'x': 221,
              'y': 224,
              'width': 69,
              'height': 46,
              'materialKey': 'biome_water',
            },
          ];
        case 'filled':
          shapes[1]['collisionMode'] = 'solid';
        case 'uneven':
          for (final v in shapes.last['vertices'] as List) {
            if (v['y'] == 224) v['y'] = 225;
          }
        case 'oneWay':
          shapes.last['collisionMode'] = 'oneWay';
        case 'missing':
          shapes.removeLast();
      }
      expect(gaps(json), isEmpty);
    });
  }
}
