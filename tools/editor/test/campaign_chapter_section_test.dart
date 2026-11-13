import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_chapter_section.dart';

void main() {
  testWidgets('compact chapter sidebar spaces actions and hides metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = CampaignCatalogSource.decode(
      File('${Directory.current.parent.parent.path}/$campaignSourcePath')
          .readAsStringSync(),
    );
    final chapter = catalog.chapters.first;
    var settingsOpened = false;
    var rewardsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CampaignChapterSection(
                chapter: chapter,
                number: 1,
                selectedMissionId: chapter.missions.first.id,
                onSettings: () => settingsOpened = true,
                onRewards: () => rewardsOpened = true,
                onAddMission: () {},
                onSelectMission: (_) {},
                onReorderMission: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(chapter.description['en']!), findsNothing);
    expect(find.textContaining('Chapter rewards:'), findsNothing);
    final settings = find.widgetWithText(OutlinedButton, 'Chapter settings');
    final rewards = find.widgetWithText(OutlinedButton, 'Chapter rewards');
    final settingsRect = tester.getRect(settings);
    final rewardsRect = tester.getRect(rewards);
    expect(
      rewardsRect.left >= settingsRect.right + 8 ||
          rewardsRect.top >= settingsRect.bottom + 8,
      isTrue,
    );
    final firstMission = find.byKey(
      ValueKey('campaign_mission_${chapter.missions.first.id}'),
    );
    expect(
      tester.getTopLeft(firstMission).dy,
      greaterThanOrEqualTo(rewardsRect.bottom + 12),
    );
    await tester.tap(settings);
    await tester.tap(rewards);
    expect(settingsOpened, isTrue);
    expect(rewardsOpened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
