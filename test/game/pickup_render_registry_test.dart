import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/components/pickups/pickup_render_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final character in PlayerCharacterId.values) {
    test('loads $character resource gem art from the real sheet', () async {
      final images = Images();
      addTearDown(images.clearCache);
      final registry = PickupRenderRegistry(playerCharacter: character);
      await registry.load(images);

      final expectedRows = {
        PickupVariant.restorationHealth: 0,
        PickupVariant.restorationMana:
            character == PlayerCharacterId.bountyHunter ? 3 : 1,
        PickupVariant.restorationStamina: 2,
      };
      for (final entry in expectedRows.entries) {
        final view = registry.entryForVariant(entry.key);
        final animation = view.animSet.animations[AnimKey.idle]!;
        expect(animation.loop, isTrue);
        expect(animation.frames, hasLength(12));
        expect(view.animSet.ticksPerFrameFor(AnimKey.idle, 60), 5);
        expect(view.renderScale.x, 1);
        expect(view.renderScale.y, 1);
        for (var i = 0; i < animation.frames.length; i++) {
          final frame = animation.frames[i];
          expect(frame.stepTime, 0.08);
          expect(
            frame.sprite.src,
            Rect.fromLTWH(i * 16, entry.value * 16, 16, 16),
          );
          expect(
            frame.sprite.src.right,
            lessThanOrEqualTo(frame.sprite.image.width),
          );
          expect(
            frame.sprite.src.bottom,
            lessThanOrEqualTo(frame.sprite.image.height),
          );
        }
      }
      final coin = registry
          .entryForVariant(PickupVariant.collectible)
          .animSet
          .animations[AnimKey.idle]!;
      expect(coin.frames, hasLength(7));
      expect(coin.frames.first.stepTime, 0.1);
    });
  }
}
