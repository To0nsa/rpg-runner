import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Source-pixel animation regions and pivot for VoidTentacle.
abstract final class VoidTentacleRenderCatalog {
  static const actor = RenderAnimSetDefinition(
    frameWidth: 171,
    frameHeight: 136,
    anchorPoint: Vec2(78, 110),
    sourcesByKey: {
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.walk:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.run:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.strike:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
      AnimKey.death:
          'entities/enemies/ancient_god_pack/voidcaller/sprite_sheet.png',
    },
    rowByKey: {
      AnimKey.spawn: 16,
      AnimKey.idle: 17,
      AnimKey.walk: 17,
      AnimKey.run: 17,
      AnimKey.strike: 18,
      AnimKey.hit: 19,
      AnimKey.death: 20,
    },
    frameCountsByKey: {
      AnimKey.spawn: 5,
      AnimKey.idle: 6,
      AnimKey.walk: 6,
      AnimKey.run: 6,
      AnimKey.strike: 7,
      AnimKey.hit: 3,
      AnimKey.death: 6,
    },
    stepTimeSecondsByKey: {
      AnimKey.spawn: .1,
      AnimKey.idle: .1,
      AnimKey.walk: .1,
      AnimKey.run: .1,
      AnimKey.strike: .1,
      AnimKey.hit: .1,
      AnimKey.death: .1,
    },
  );
}
