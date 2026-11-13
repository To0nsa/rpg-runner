import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:test/test.dart';

void main() {
  final lesson = CampaignDecorationTutorial.introduction(
    missionChunkId: 'second',
    waterRegionId: 'pool',
    decorationPrefabKey: 'tree',
  );
  test('decoration contract is bilingual, strict and reveals no extra HUD', () {
    expect(decodeCampaignTutorial(lesson.toJson()).toJson(), lesson.toJson());
    expect(lesson.reveals, isEmpty);
    expect(lesson.continuationAt(0), CampaignTutorialContinuation.movement);
    expect(lesson.optional, isFalse);
    expect(lesson.target.isWorld, isTrue);
    for (final field in [
      'missionChunkId',
      'waterRegionId',
      'decorationPrefabKey',
      'instruction',
      'spotlight',
    ]) {
      expect(
        () => decodeCampaignTutorial(lesson.toJson()..[field] = null),
        throwsFormatException,
      );
    }
    expect(
      () => decodeCampaignTutorial(lesson.toJson()..['unexpected'] = 1),
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
    expect(() => lesson.instruction['fr'] = 'changed', throwsUnsupportedError);
  });
  ChunkVisualSpriteRel sprite({
    String? key = 'tree',
    bool decoration = true,
    double rotation = 0,
  }) => ChunkVisualSpriteRel(
    prefabKey: key,
    assetPath: 'tree.png',
    srcX: 0,
    srcY: 0,
    srcWidth: 100,
    srcHeight: 50,
    x: 20,
    y: 30,
    width: 100,
    height: 50,
    isDecoration: decoration,
    rotationDegrees: rotation,
  );
  test('selection excludes missing, solid and ambiguous prefab references', () {
    final tree = sprite();
    expect(campaignTutorialDecorations([tree]), [tree]);
    expect(campaignTutorialDecorations([tree, sprite()]), isEmpty);
    expect(
      campaignTutorialDecorations([
        sprite(key: null),
        sprite(decoration: false),
      ]),
      isEmpty,
    );
  });
  test('spotlight uses rendered bounds including center rotation', () {
    final bounds = campaignTutorialSpriteBounds(sprite(rotation: 90));
    expect(bounds.x, closeTo(45, 1e-9));
    expect(bounds.y, closeTo(5, 1e-9));
    expect(bounds.width, closeTo(50, 1e-9));
    expect(bounds.height, closeTo(100, 1e-9));
  });
}
