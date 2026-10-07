import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Source-pixel animation regions and pivot for Voidcaller.
abstract final class VoidcallerRenderCatalog {
  static const actor = RenderAnimSetDefinition(
    frameWidth: 171,
    frameHeight: 136,
    anchorPoint: Vec2(83, 104),
    sourcesByKey: {
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.walk:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.run:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.cast:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.ranged:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.strike2:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.death:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
    },
    rowByKey: {
      AnimKey.idle: 0,
      AnimKey.walk: 1,
      AnimKey.run: 1,
      AnimKey.cast: 2,
      AnimKey.ranged: 3,
      AnimKey.strike2: 4,
      AnimKey.spawn: 3,
      AnimKey.hit: 21,
      AnimKey.death: 22,
    },
    frameCountsByKey: {
      AnimKey.idle: 8,
      AnimKey.walk: 8,
      AnimKey.run: 8,
      AnimKey.cast: 17,
      AnimKey.ranged: 17,
      AnimKey.strike2: 10,
      AnimKey.spawn: 17,
      AnimKey.hit: 3,
      AnimKey.death: 9,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .1,
      AnimKey.walk: .1,
      AnimKey.run: .1,
      AnimKey.cast: .1,
      AnimKey.ranged: .1,
      AnimKey.strike2: .1,
      AnimKey.spawn: .1,
      AnimKey.hit: .1,
      AnimKey.death: .1,
    },
  );
  static const claw = RenderAnimSetDefinition(
    frameWidth: 171,
    frameHeight: 136,
    anchorPoint: Vec2(78, 119),
    sourcesByKey: {
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
    },
    rowByKey: {AnimKey.spawn: 15, AnimKey.idle: 15, AnimKey.hit: 15},
    frameStartByKey: {AnimKey.idle: 2, AnimKey.hit: 5},
    frameCountsByKey: {AnimKey.spawn: 2, AnimKey.idle: 3, AnimKey.hit: 3},
    stepTimeSecondsByKey: {
      AnimKey.spawn: .08,
      AnimKey.idle: .08,
      AnimKey.hit: .08,
    },
  );
}
