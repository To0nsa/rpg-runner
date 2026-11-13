import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:test/test.dart';

void main() {
  final lesson = CampaignCombatTutorial.introduction(
    missionChunkId: 'mission_chunk_10',
    markerSalt: 1,
  );
  test('combat round trip retains marker, ordered pages and bilingual practice hint', () {
    expect(decodeCampaignTutorial(lesson.toJson()).toJson(), lesson.toJson());
    expect(lesson.continuationAt(1), CampaignTutorialContinuation.projectile);
    expect(lesson.continuationAt(2), CampaignTutorialContinuation.primary);
    lesson.validateTarget(campaignMissions['reporting_for_duty']!);
    final source = CampaignCatalogSource.decode(
      File('../../assets/authoring/campaign/chapter_defs.json')
          .readAsStringSync(),
    );
    expect(
      source.chapters.first.missions.first.tutorialSequences.last.toJson(),
      lesson.toJson(),
    );
  });
  test(
    'combat rejects malformed pages, early sword reveal and missing targets',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j['markerSalt'] = -1,
        (j) => j['approachDistance'] = double.nan,
        (j) => j['practiceHint']['fr'] = '',
        (j) => j['steps'][1]['reveals'] = [],
        (j) => j['steps'][0]['reveals'] = ['primary'],
        (j) => j['steps'][2]['target'] = 'projectile',
      ]) {
        final json =
            jsonDecode(jsonEncode(lesson.toJson())) as Map<String, dynamic>;
        mutate(json);
        expect(() => decodeCampaignTutorial(json), throwsFormatException);
      }
      final missing = CampaignCombatTutorial.decode(
        lesson.toJson()..['markerSalt'] = 999,
      );
      expect(
        () => missing.validateTarget(campaignMissions['reporting_for_duty']!),
        throwsFormatException,
      );
      expect(
        () => decodeCampaignTutorials([lesson.toJson(), lesson.toJson()]),
        throwsFormatException,
      );
    },
  );
}
