import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:test/test.dart';

void main() {
  final preset = CampaignBlessingTutorial.introduction(shrineId: 'basin');
  test('blessing pages retain ordered targets, languages and real-input continuations', () {
    final lesson =
        decodeCampaignTutorial(preset.toJson()) as CampaignBlessingTutorial;
    expect(lesson.toJson(), preset.toJson());
    expect(lesson.steps, hasLength(3));
    expect(
      [for (var i = 0; i < 3; i++) lesson.continuationAt(i)],
      [
        CampaignTutorialContinuation.movement,
        CampaignTutorialContinuation.next,
        CampaignTutorialContinuation.movement,
      ],
    );
    for (final step in lesson.steps) {
      expect(step.title.keys, containsAll(['en', 'fr']));
      expect(step.instruction.keys, containsAll(['en', 'fr']));
    }
    expect(() => lesson.steps.clear(), throwsUnsupportedError);
  });
  test('blessing schema rejects missing fields, languages, order and essential reveals', () {
    for (final field in ['shrineId', 'steps', 'approachDistance']) {
      expect(
        () => decodeCampaignTutorial(preset.toJson()..[field] = null),
        throwsFormatException,
      );
    }
    for (final distance in [0, 601, double.nan]) {
      expect(
        () => decodeCampaignTutorial(
          preset.toJson()..['approachDistance'] = distance,
        ),
        throwsFormatException,
      );
    }
    for (final change in ['target', 'translation', 'reveal']) {
      final data = preset.toJson();
      final steps = data['steps'] as List;
      switch (change) {
        case 'target':
          steps[2]['target'] = 'resources';
        case 'translation':
          steps[1]['instruction'] = {'en': 'Incomplete'};
        case 'reveal':
          steps[0]['reveals'] = ['objectives'];
      }
      expect(() => decodeCampaignTutorial(data), throwsFormatException);
    }
    expect(
      () => decodeCampaignTutorial(preset.toJson()..['extra'] = true),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorials([preset.toJson(), preset.toJson()]),
      throwsFormatException,
    );
  });
}
