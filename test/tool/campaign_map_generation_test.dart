import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';

import '../../tool/content_build_report.dart';
import '../../tool/generate_chunk_runtime_data.dart';

void main() {
  test('generated game presentation matches the authored campaign', () {
    final source = CampaignCatalogSource.decode(
      File(campaignSourcePath).readAsStringSync(),
    );
    expect(CampaignCatalog.title('en'), source.title['en']);
    expect(CampaignCatalog.title('fr'), source.title['fr']);
    expect(CampaignCatalog.title('unknown'), source.title['en']);
    expect(CampaignCatalog.mapAssetPath, source.map.assetPath);
    for (final mission in source.missions) {
      final display = CampaignCatalog.mission(mission.id)!;
      expect(display.firstClearXp, mission.firstClearXp);
      expect(display.firstClearGold, mission.firstClearGold);
      expect(
        display.firstClearItems.map((gift) => gift.toJson()),
        mission.firstClearItems.map((gift) => gift.toJson()),
      );
    }
    expect(
      CampaignCatalog.mapAspectRatio,
      source.map.width / source.map.height,
    );
  });

  test('Build captures maps, emits presentation and rejects dimension or image drift', () async {
    final root = Directory.systemTemp.createTempSync('campaign_map_build_');
    addTearDown(() {
      expect(
        root.absolute.path,
        startsWith(Directory.systemTemp.absolute.path),
      );
      root.deleteSync(recursive: true);
    });
    final json = jsonDecode(
      File(campaignSourcePath).readAsStringSync(),
    ) as Map<String, dynamic>;
    json['title'] = {'en': 'Example', 'fr': 'Exemple'};
    json['map'] = {
      'assetPath': 'assets/images/maps/example.png',
      'width': 1,
      'height': 1,
    };
    for (final chapter in json['chapters'] as List) {
      for (final mission in chapter['missions'] as List) {
        mission['includeInBuild'] = false;
        mission['firstClearGold'] = 123;
        mission['firstClearItems'] = [
          {'kind': 'gear', 'slot': 'mainWeapon', 'itemId': 'cinderedge'},
          {
            'kind': 'ability',
            'slot': 'jump',
            'itemId': 'eloise.double_jump',
            'characterId': 'eloise',
          },
        ];
      }
    }
    final source = File('${root.path}/$campaignSourcePath');
    source.parent.createSync(recursive: true);
    source.writeAsStringSync(jsonEncode(json));
    final map = File('${root.path}/assets/images/maps/example.png');
    map.parent.createSync(recursive: true);
    map.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ1sAAAAASUVORK5CYII=',
      ),
    );
    final catalog = CampaignCatalogSource.decode(jsonEncode(json));
    final levels = catalog.missions.map((m) => m.levelId).toSet();
    final themes = catalog.missions.map((m) => m.visualThemeId).toSet();
    final snapshot = await ContentBuildSnapshot.capture(
      workspaceRoot: root.path,
    );
    final outputs = buildCampaignArtifacts(snapshot, levels, themes);
    final ui = outputs.singleWhere(
      (o) => o.path == 'lib/ui/campaign/generated_campaign_catalog.dart',
    );
    expect(ui.content, contains('"en": "Example"'));
    expect(
      ui.content,
      contains('"assetPath": "assets/images/maps/example.png"'),
    );
    final server = outputs.singleWhere(
      (o) => o.path == 'functions/src/campaign/generated_catalog.ts',
    );
    final projected = jsonDecode(
      server.content
          .split('export const campaignCatalog = ')[1]
          .split(' as const;')[0],
    ) as Map<String, dynamic>;
    for (final chapter in projected['chapters'] as List) {
      for (final mission in chapter['missions'] as List) {
        final display = CampaignMission(
          Map<String, Object?>.from(mission as Map),
        );
        expect(display.firstClearGold, 123);
        expect(display.firstClearItems.map((gift) => gift.item.itemId), [
          'cinderedge',
          'eloise.double_jump',
        ]);
        expect(display.firstClearItems.last.characterId, 'eloise');
      }
    }
    map.writeAsStringSync('corrupt');
    await expectLater(
      snapshot.verifyCurrent(),
      throwsA(isA<ContentBuildInterruption>()),
    );
    final corrupt = await ContentBuildSnapshot.capture(
      workspaceRoot: root.path,
    );
    expect(
      () => buildCampaignArtifacts(corrupt, levels, themes),
      throwsFormatException,
    );
    map.writeAsBytesSync(snapshot.readBytes(catalog.map.assetPath));
    (json['map'] as Map)['width'] = 2;
    source.writeAsStringSync(jsonEncode(json));
    final changed = await ContentBuildSnapshot.capture(
      workspaceRoot: root.path,
    );
    expect(
      () => buildCampaignArtifacts(changed, levels, themes),
      throwsFormatException,
    );
    map.deleteSync();
    final missing = await ContentBuildSnapshot.capture(
      workspaceRoot: root.path,
    );
    expect(
      () => buildCampaignArtifacts(missing, levels, themes),
      throwsA(isA<FileSystemException>()),
    );
  });
}
