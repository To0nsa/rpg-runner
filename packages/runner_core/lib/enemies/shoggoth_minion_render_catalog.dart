import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Source-pixel animation regions and pivot for ShoggothMinion.
abstract final class ShoggothMinionRenderCatalog {
  static const actor = RenderAnimSetDefinition(
    frameWidth: 149,
    frameHeight: 114,
    anchorPoint: Vec2(79, 59),
    sourcesByKey: {
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.walk:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.run:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.strike:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
      AnimKey.death:
          'entities/enemies/ancient_god_pack/shoggoth/sprite_sheet.png',
    },
    rowByKey: {
      AnimKey.idle: 10,
      AnimKey.walk: 11,
      AnimKey.run: 11,
      AnimKey.spawn: 10,
      AnimKey.strike: 12,
      AnimKey.hit: 13,
      AnimKey.death: 14,
    },
    frameCountsByKey: {
      AnimKey.idle: 4,
      AnimKey.walk: 4,
      AnimKey.run: 4,
      AnimKey.spawn: 4,
      AnimKey.strike: 6,
      AnimKey.hit: 3,
      AnimKey.death: 5,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .1,
      AnimKey.walk: .1,
      AnimKey.run: .1,
      AnimKey.spawn: .1,
      AnimKey.strike: .1,
      AnimKey.hit: .1,
      AnimKey.death: .1,
    },
  );
}
