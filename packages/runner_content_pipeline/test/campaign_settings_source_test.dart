import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

void main() {
  final source = File('../../assets/authoring/campaign/chapter_defs.json')
      .readAsStringSync();

  test(
    'campaign presentation round-trips without changing mission identities',
    () {
      final original = CampaignCatalogSource.decode(source);
      final json = original.toJson()
        ..['title'] = {'en': 'The Long Run', 'fr': 'La longue course'}
        ..['map'] = {
          'assetPath': 'assets/images/maps/lothringen_bonfire.jpg',
          'width': 2400,
          'height': 1600,
        };
      final changed = CampaignCatalogSource.decode(jsonEncode(json));
      expect(changed.title['fr'], 'La longue course');
      expect(changed.map.width / changed.map.height, 1.5);
      expect(jsonDecode(changed.encode()), json);
      expect(
        changed.chapters.map((c) => c.toJson()),
        original.chapters.map((c) => c.toJson()),
      );
    },
  );

  test('campaign map rejects nonportable paths, unsupported types and bad dimensions', () {
    for (final path in [
      '../map.png',
      '/tmp/map.png',
      r'C:\maps\map.png',
      'assets/images/maps/../map.png',
      'assets/images/maps/Map Name.jpg',
      'assets/images/maps/map.svg',
      'assets/images/maps/region/map.png',
      'assets/images/maps/map.png/escape.png',
    ]) {
      expect(
        () => CampaignMapSource.decode({
          'assetPath': path,
          'width': 1,
          'height': 1,
        }),
        throwsFormatException,
        reason: path,
      );
    }
    for (final dimension in [0, -1, 1.5, null, 32769]) {
      expect(
        () => CampaignMapSource.decode({
          'assetPath': 'assets/images/maps/map.png',
          'width': dimension,
          'height': 1,
        }),
        throwsFormatException,
      );
    }
    for (final title in [
      null,
      {'en': 'Name'},
      {'en': '', 'fr': 'Nom'},
    ]) {
      expect(
        () => CampaignCatalogSource.decode(
          jsonEncode(jsonDecode(source)..['title'] = title),
        ),
        throwsFormatException,
      );
    }
  });
}
