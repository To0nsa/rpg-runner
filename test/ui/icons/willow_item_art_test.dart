import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_presentation/gear_icon.dart';
import 'package:game_presentation/projectile_icon_frame.dart';
import 'package:game_presentation/ui_icon_coords.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';

void main() {
  final weapons = WeaponId.values.where((id) => id.name.startsWith('hunter'));
  final kits = SpellBookId.values.where((id) => id.name.startsWith('hunter'));

  testWidgets(
    'all 34 Willow illustrations are distinct bundled transparent PNGs',
    (tester) async {
      final paths = <String?>[
        for (final id in weapons) uiIconSpecForWeapon(id).imageAssetPath,
        for (final id in kits) uiImageAssetPathForSpellBook(id),
        for (final id in hunterRangedWeaponIds)
          uiImageAssetPathForProjectile(id),
      ];
      expect(paths, hasLength(34));
      expect(paths, everyElement(isNotNull));
      expect(paths.toSet(), hasLength(34));

      await tester.runAsync(() async {
        for (final path in paths.cast<String>()) {
          expect(path, startsWith('assets/images/icons/gear-icons/willow/'));
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
                expect(alpha, 0, reason: 'Transparent margin: $path ($x, $y)');
              }
            }
          }
          expect(visiblePixels, greaterThan(100), reason: path);
          expect(visiblePixels, lessThan(3500), reason: path);
          image.dispose();
          codec.dispose();
        }
      });
    },
  );

  testWidgets(
    'shared gear and ranged widgets load every Willow item at menu sizes',
    (tester) async {
      for (final size in <double>[32, 40, 64]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Wrap(
                children: [
                  for (final id in weapons)
                    GearIcon(slot: GearSlot.mainWeapon, id: id, size: size),
                  for (final id in kits)
                    GearIcon(slot: GearSlot.spellBook, id: id, size: size),
                  for (final id in hunterRangedWeaponIds)
                    ProjectileIconFrame(projectileId: id, size: size),
                ],
              ),
            ),
          ),
        );
        await _waitForImages(tester);
        final images = tester.widgetList<RawImage>(find.byType(RawImage));
        expect(images, hasLength(34));
        for (final image in images) {
          expect(image.image, isNotNull);
          expect(image.width, size);
          expect(image.height, size);
          expect(image.filterQuality, FilterQuality.none);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'ranged illustration clears when the selected item becomes unknown',
    (tester) async {
      for (final id in [
        ProjectileId.hunterPistol,
        ProjectileId.unknown,
        ProjectileId.hunterCrossbow,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: ProjectileIconFrame(projectileId: id)),
          ),
        );
        if (id == ProjectileId.unknown) {
          expect(find.byType(RawImage), findsNothing);
        } else {
          await _waitForImages(tester);
          final image = tester.widget<Image>(find.byType(Image));
          expect(
            (image.image as AssetImage).assetName,
            uiImageAssetPathForProjectile(id),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
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
  fail('Item images did not finish decoding');
}
