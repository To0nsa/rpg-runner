import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final lesson = CampaignMobilityTutorial.introduction(
    missionChunkId: 'eighth',
  );
  test(
    'mobility is a strict bilingual panel requiring a real action reveal',
    () {
      expect(decodeCampaignTutorial(lesson.toJson()).toJson(), lesson.toJson());
      expect(lesson.continuationAt(0), CampaignTutorialContinuation.mobility);
      expect(lesson.reveals, {TutorialHudElement.mobility});
      expect(lesson.spotlight.shape, TutorialSpotlightShape.ellipse);
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j['missionChunkId'] = '',
        (j) => j['triggerX'] = null,
        (j) => j['triggerX'] = -1,
        (j) => j['triggerX'] = 601,
        (j) => j['triggerX'] = double.nan,
        (j) => j['reveals'] = [],
        (j) => j['instruction']['fr'] = '',
        (j) => j['spotlight']['height'] = 0,
        (j) => j['extra'] = true,
      ]) {
        final json =
            jsonDecode(jsonEncode(lesson.toJson())) as Map<String, dynamic>;
        mutate(json);
        expect(() => decodeCampaignTutorial(json), throwsFormatException);
      }
      expect(
        () => decodeCampaignTutorials([lesson.toJson(), lesson.toJson()]),
        throwsFormatException,
      );
      expect(
        () => decodeCampaignTutorials([
          lesson.toJson(),
          CampaignBlessingTutorial.introduction(shrineId: 'shrine').toJson(),
        ]),
        throwsFormatException,
      );
    },
  );

  test('authored lesson follows blessing at the bush and retains chunk references', () {
    final path =
        '${Directory.current.parent.parent.path}/assets/authoring/campaign/chapter_defs.json';
    final contents = File(path).readAsStringSync();
    final source = CampaignCatalogSource.decode(contents);
    final mission = source.chapters.first.missions.first;
    final mobility = mission.tutorialSequences
        .whereType<CampaignMobilityTutorial>()
        .single;
    expect(mobility.missionChunkId, 'mission_chunk_8');
    expect(mobility.triggerX, 522);
    expect(
      mission.tutorialSequences[mission.tutorialSequences.indexOf(mobility) -
          1],
      isA<CampaignBlessingTutorial>(),
    );
    final json = jsonDecode(contents) as Map<String, dynamic>;
    final modified =
        (json['chapters'][0]['missions'][0]['tutorialSequences'] as List)
                .singleWhere((s) => s['kind'] == 'mobility')
            as Map;
    modified['missionChunkId'] = 'missing_chunk';
    modified['enabled'] = false;
    expect(
      () => CampaignCatalogSource.decode(jsonEncode(json)),
      throwsFormatException,
    );
  });
}
