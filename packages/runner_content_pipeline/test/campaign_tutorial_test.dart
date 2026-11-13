import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  test(
    'water and swimming lessons preserve strict bilingual source and behavior',
    () {
      final water = CampaignWaterTutorial.introduction(
        missionChunkId: 'mission_chunk_2',
        waterRegionId: 'water_1',
      );
      final swim = CampaignSwimmingTutorial.introduction();
      expect(decodeCampaignTutorial(water.toJson()).toJson(), water.toJson());
      expect(decodeCampaignTutorial(swim.toJson()).toJson(), swim.toJson());
      expect(water.continuationAt(0), CampaignTutorialContinuation.movement);
      expect(swim.continuationAt(0), CampaignTutorialContinuation.jump);
      expect(swim.optional, isTrue);
      expect(water.optional, isFalse);
      expect(swim.reveals, {
        TutorialHudElement.jump,
        TutorialHudElement.resources,
      });
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (json) => json['missionChunkId'] = '',
        (json) => json['waterRegionId'] = null,
        (json) => json['approachDistance'] = 0,
        (json) => json['approachDistance'] = double.infinity,
        (json) => json['approachDistance'] = 601,
        (json) => json['instruction']['fr'] = '',
        (json) => json['spotlight']['width'] = 0,
        (json) => json['extra'] = true,
      ]) {
        final json =
            jsonDecode(jsonEncode(water.toJson())) as Map<String, dynamic>;
        mutate(json);
        expect(() => decodeCampaignTutorial(json), throwsFormatException);
      }
      for (final reveals in [
        <String>[],
        ['jump'],
        ['resources'],
      ]) {
        expect(
          () => decodeCampaignTutorial(swim.toJson()..['reveals'] = reveals),
          throwsFormatException,
        );
      }
      expect(
        () => decodeCampaignTutorials([swim.toJson(), water.toJson()]),
        throwsFormatException,
      );
      expect(() => swim.instruction['en'] = 'changed', throwsUnsupportedError);
    },
  );
  Map<String, dynamic> preset() => jsonDecode(
    jsonEncode(CampaignMovementTutorial.movementIntroduction().toJson()),
  ) as Map<String, dynamic>;

  test(
    'movement preset preserves languages and independent control shapes',
    () {
      final tutorial = CampaignMovementTutorial.decode(preset());
      expect(tutorial.toJson(), preset());
      expect(
        tutorial.instructionFor(TutorialMovementControl.arrows, 'fr'),
        contains('Maintiens'),
      );
      expect(
        tutorial.instructionFor(TutorialMovementControl.keyboard, 'de'),
        tutorial.instructions[TutorialMovementControl.keyboard]!['en'],
      );
      expect(
        tutorial.spotlights[TutorialMovementControl.fixedJoystick]!.shape,
        TutorialSpotlightShape.ellipse,
      );
      expect(
        () => tutorial.instructions[TutorialMovementControl.arrows]!['fr'] =
            'changed',
        throwsUnsupportedError,
      );
    },
  );

  test('strict source rejects unsupported triggers, fields and variants', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (json) => json['trigger'] = 'region',
      (json) => json['enabled'] = 'true',
      (json) => json['kind'] = 'combat',
      (json) => json['extra'] = true,
      (json) => (json['instructions'] as Map).remove('keyboard'),
      (json) => json['title']['fr'] = '',
      (json) => json['spotlights']['arrows']['width'] = 0,
      (json) => json['spotlights']['arrows']['x'] = double.nan,
    ]) {
      final json = preset();
      mutate(json);
      expect(
        () => CampaignMovementTutorial.decode(json),
        throwsFormatException,
      );
    }
    expect(() => decodeCampaignTutorials(null), throwsFormatException);
    expect(
      () => decodeCampaignTutorials([preset(), preset()]),
      throwsFormatException,
    );
  });

  test('ordered objectives and coin lessons and HUD configuration remain strict and immutable', () {
    final movement = CampaignMovementTutorial.movementIntroduction();
    expect(
      () => decodeCampaignTutorial(movement.toJson()..['reveals'] = null),
      throwsFormatException,
    );
    final objectives = CampaignObjectivesTutorial.introduction();
    final coin = CampaignCoinTutorial.introduction();
    final sequence = decodeCampaignTutorials([
      movement.toJson(),
      objectives.toJson(),
      coin.toJson(),
    ]);
    expect(sequence[1].target, CampaignTutorialTarget.objectives);
    expect(
      decodeCampaignTutorial(objectives.toJson()).toJson(),
      objectives.toJson(),
    );
    expect(
      () => decodeCampaignTutorial(objectives.toJson()..['reveals'] = []),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorials([coin.toJson(), objectives.toJson()]),
      throwsFormatException,
    );
    expect(sequence.last.trigger, CampaignTutorialTrigger.firstCoinCollected);
    expect(sequence.last.reveals, {TutorialHudElement.runStats});
    expect(decodeCampaignTutorial(coin.toJson()).toJson(), coin.toJson());
    expect(
      () => decodeCampaignTutorials([coin.toJson(), movement.toJson()]),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorials([coin.toJson(), coin.toJson()]),
      throwsFormatException,
    );
    expect(
      () => decodeCampaignTutorial(coin.toJson()..['reveals'] = []),
      throwsFormatException,
    );
    expect(
      () => decodeTutorialHud(['jump'], initial: true),
      throwsFormatException,
    );
    expect(
      () => decodeTutorialHud(['movement', 'movement']),
      throwsFormatException,
    );
    expect(() => decodeTutorialHud(['unknown']), throwsFormatException);
    expect(() => coin.reveals.clear(), throwsUnsupportedError);
  });

  test(
    'mission optional tutorials round-trip and remain outside Core definition',
    () {
      final file = File('../../assets/authoring/campaign/chapter_defs.json');
      final catalog = CampaignCatalogSource.decode(file.readAsStringSync());
      final mission = catalog.missions.first.toJson()
        ..['tutorialSequences'] = [preset()];
      final decoded = CampaignMissionSource.decode(mission);
      expect(decoded.toJson(), mission);
      expect(decoded.tutorialSequences.single.enabled, isTrue);
      mission.remove('tutorialSequences');
      expect(CampaignMissionSource.decode(mission).tutorialSequences, isEmpty);
      mission['tutorialSequences'] = null;
      expect(
        () => CampaignMissionSource.decode(mission),
        throwsFormatException,
      );
    },
  );
  test('jump sequence has three immutable ordered pages and strict bounds', () {
    final sequence = CampaignJumpTutorial.introduction(
      missionChunkId: 'mission_chunk_2',
    );
    final decoded =
        decodeCampaignTutorial(sequence.toJson()) as CampaignJumpTutorial;
    expect(decoded.toJson(), sequence.toJson());
    expect(decoded.stepCount, 3);
    expect(decoded.targetAt(1), CampaignTutorialTarget.jump);
    expect(decoded.continuationAt(0), CampaignTutorialContinuation.next);
    expect(decoded.continuationAt(2), CampaignTutorialContinuation.jump);
    expect(decoded.revealsAt(2), {TutorialHudElement.resources});
    expect(() => decoded.steps.clear(), throwsUnsupportedError);
    expect(
      () => decoded.steps[0].title['fr'] = 'changed',
      throwsUnsupportedError,
    );
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (json) => json['steps'].removeLast(),
      (json) => json['steps'][1]['target'] = 'resources',
      (json) => json['steps'][1]['reveals'] = [],
      (json) => json['steps'][2]['title']['fr'] = '',
      (json) => json['obstacle']['width'] = 600,
      (json) => json['obstacle']['x'] = double.nan,
      (json) => json['steps'][0]['extra'] = true,
    ]) {
      final json =
          jsonDecode(jsonEncode(sequence.toJson())) as Map<String, dynamic>;
      mutate(json);
      expect(() => decodeCampaignTutorial(json), throwsFormatException);
    }
  });

  test('chunk tutorial follows route identity and rejects a removed chunk', () {
    final catalog = CampaignCatalogSource.decode(
      File('../../assets/authoring/campaign/chapter_defs.json')
          .readAsStringSync(),
    );
    final json = catalog.missions.first.toJson();
    final lesson = CampaignJumpTutorial.introduction(
      missionChunkId: 'mission_chunk_2',
    );
    json['tutorialSequences'] = [lesson.toJson()];
    final route = json['route'] as List;
    final first = route.removeAt(0);
    route.add(first);
    expect(
      CampaignMissionSource.decode(json).tutorialSequences.single.toJson(),
      lesson.toJson(),
    );
    route.removeWhere((chunk) => chunk['id'] == 'mission_chunk_2');
    expect(() => CampaignMissionSource.decode(json), throwsFormatException);
  });
}
