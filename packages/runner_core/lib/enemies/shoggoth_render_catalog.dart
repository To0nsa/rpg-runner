import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Source-pixel animation regions and pivot for Shoggoth.
abstract final class ShoggothRenderCatalog {
  static const actor = RenderAnimSetDefinition(
    frameWidth: 149,
    frameHeight: 114,
    anchorPoint: Vec2(79, 65),
    sourcesByKey: {
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.walk:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.run:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.teleportOut:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.strike:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.strike2:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.cast:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.ranged:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.death:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
    },
    rowByKey: {
      AnimKey.idle: 0,
      AnimKey.walk: 1,
      AnimKey.run: 1,
      AnimKey.teleportOut: 2,
      AnimKey.spawn: 3,
      AnimKey.strike: 4,
      AnimKey.strike2: 5,
      AnimKey.cast: 6,
      AnimKey.ranged: 9,
      AnimKey.hit: 15,
      AnimKey.death: 16,
    },
    frameCountsByKey: {
      AnimKey.idle: 8,
      AnimKey.walk: 8,
      AnimKey.run: 8,
      AnimKey.teleportOut: 6,
      AnimKey.spawn: 9,
      AnimKey.strike: 11,
      AnimKey.strike2: 12,
      AnimKey.cast: 11,
      AnimKey.ranged: 9,
      AnimKey.hit: 3,
      AnimKey.death: 8,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .1,
      AnimKey.walk: .1,
      AnimKey.run: .1,
      AnimKey.teleportOut: .1,
      AnimKey.spawn: .1,
      AnimKey.strike: .1,
      AnimKey.strike2: .1,
      AnimKey.cast: .1,
      AnimKey.ranged: .1,
      AnimKey.hit: .1,
      AnimKey.death: .1,
    },
  );
  static const orb = RenderAnimSetDefinition(
    frameWidth: 149,
    frameHeight: 114,
    anchorPoint: Vec2(61, 66),
    sourcesByKey: {
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
    },
    rowByKey: {AnimKey.idle: 7, AnimKey.hit: 8},
    frameCountsByKey: {AnimKey.idle: 6, AnimKey.hit: 5},
    stepTimeSecondsByKey: {AnimKey.idle: .08, AnimKey.hit: .08},
  );
}
