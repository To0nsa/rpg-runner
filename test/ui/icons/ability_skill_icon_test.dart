import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_presentation/ability_skill_icon.dart';
import 'package:runner_core/abilities/catalog/bounty_hunter_ability_defs.dart';
import 'package:runner_core/abilities/catalog/eloise_ability_defs.dart';

void main() {
  final ids = {...eloiseAbilityDefs.keys, ...bountyHunterAbilityDefs.keys};

  testWidgets('every playable ability has a unique bundled transparent icon', (
    tester,
  ) async {
    expect(abilitySkillIconAssets.keys.toSet(), ids);
    expect(abilitySkillIconAssets.values.toSet(), hasLength(ids.length));
    await tester.runAsync(() async {
      for (final path in abilitySkillIconAssets.values) {
        final bytes = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 64, reason: path);
        expect(image.height, 64, reason: path);
        final rgba = (await image.toByteData())!;
        var visiblePixels = 0;
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            final alpha = rgba.getUint8((y * 64 + x) * 4 + 3);
            if (alpha > 0) visiblePixels++;
            if (x == 0 || x == 63 || y == 0 || y == 63) {
              // Preserve generated alpha; 1/255 edge noise is visually transparent.
              expect(
                alpha,
                lessThanOrEqualTo(1),
                reason: 'Transparent margin: $path ($x, $y)',
              );
            }
          }
        }
        expect(visiblePixels, greaterThan(100), reason: path);
        expect(visiblePixels, lessThan(3500), reason: path);
        image.dispose();
        codec.dispose();
      }
    });
  });

  testWidgets('all ability icons load sharply at menu sizes', (tester) async {
    for (final size in <double>[32, 40, 64]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final id in ids)
                  AbilitySkillIcon(abilityId: id, size: size),
              ],
            ),
          ),
        ),
      );
      await _waitForImages(tester);
      final images = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(images, hasLength(ids.length));
      for (final image in images) {
        expect(image.image, isNotNull);
        expect(image.filterQuality, FilterQuality.none);
      }
      for (final element in find.byType(AbilitySkillIcon).evaluate()) {
        expect(
          tester.getSize(find.byWidget(element.widget)),
          Size.square(size),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('selection changes clear unknown and null ability artwork', (
    tester,
  ) async {
    for (final id in <String?>[
      'eloise.dash',
      'unknown.ability',
      null,
      'bounty_hunter.dash',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: AbilitySkillIcon(abilityId: id, size: 40)),
        ),
      );
      expect(tester.getSize(find.byType(AbilitySkillIcon)), const Size(40, 40));
      if (id == null || !abilitySkillIconAssets.containsKey(id)) {
        expect(find.byType(Image), findsNothing);
      } else {
        await _waitForImages(tester);
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          abilitySkillIconAssets[id],
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _waitForImages(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final images = tester.widgetList<RawImage>(find.byType(RawImage));
    if (images.isNotEmpty && images.every((image) => image.image != null)) {
      return;
    }
  }
  fail('Ability images did not finish decoding');
}
