import '../contracts/render_frame_rect.dart';
import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

/// Source-pixel animation regions and pivot for VoidbornGoddess.
abstract final class VoidbornGoddessRenderCatalog {
  static const actor = RenderAnimSetDefinition(
    frameWidth: 138,
    frameHeight: 93,
    anchorPoint: Vec2(69, 63),
    sourcesByKey: {
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.walk:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.run:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.cast:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.teleportOut:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.ranged:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.strike:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.death:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
    },
    sourceFramesByKey: {
      AnimKey.ranged: [
        RenderFrameRect(0, 465, 138, 93),
        RenderFrameRect(138, 465, 138, 93),
        RenderFrameRect(276, 465, 138, 93),
        RenderFrameRect(414, 465, 138, 93),
        RenderFrameRect(552, 465, 138, 93),
        RenderFrameRect(690, 465, 138, 93),
        RenderFrameRect(0, 558, 138, 93),
        RenderFrameRect(138, 558, 138, 93),
        RenderFrameRect(276, 558, 138, 93),
        RenderFrameRect(414, 558, 138, 93),
        RenderFrameRect(552, 558, 138, 93),
        RenderFrameRect(690, 558, 138, 93),
        RenderFrameRect(828, 558, 138, 93),
        RenderFrameRect(966, 558, 138, 93),
        RenderFrameRect(1104, 558, 138, 93),
        RenderFrameRect(1242, 558, 138, 93),
        RenderFrameRect(1380, 558, 138, 93),
        RenderFrameRect(1518, 558, 138, 93),
        RenderFrameRect(1656, 558, 138, 93),
        RenderFrameRect(1794, 558, 138, 93),
        RenderFrameRect(1932, 558, 138, 93),
        RenderFrameRect(2070, 558, 138, 93),
        RenderFrameRect(2208, 558, 138, 93),
        RenderFrameRect(2346, 558, 138, 93),
        RenderFrameRect(2484, 558, 138, 93),
        RenderFrameRect(2622, 558, 138, 93),
        RenderFrameRect(2760, 558, 138, 93),
        RenderFrameRect(2898, 558, 138, 93),
        RenderFrameRect(3036, 558, 138, 93),
        RenderFrameRect(3174, 558, 138, 93),
        RenderFrameRect(3312, 558, 138, 93),
        RenderFrameRect(3450, 558, 138, 93),
        RenderFrameRect(3588, 558, 138, 93),
        RenderFrameRect(3726, 558, 138, 93),
        RenderFrameRect(3864, 558, 138, 93),
        RenderFrameRect(4002, 558, 138, 93),
      ],
    },
    rowByKey: {
      AnimKey.idle: 0,
      AnimKey.walk: 1,
      AnimKey.run: 1,
      AnimKey.cast: 2,
      AnimKey.teleportOut: 3,
      AnimKey.spawn: 4,
      AnimKey.ranged: 6,
      AnimKey.strike: 7,
      AnimKey.hit: 12,
      AnimKey.death: 13,
    },
    frameCountsByKey: {
      AnimKey.idle: 8,
      AnimKey.walk: 8,
      AnimKey.run: 8,
      AnimKey.cast: 11,
      AnimKey.teleportOut: 4,
      AnimKey.spawn: 5,
      AnimKey.ranged: 36,
      AnimKey.strike: 19,
      AnimKey.hit: 3,
      AnimKey.death: 14,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .1,
      AnimKey.walk: .1,
      AnimKey.run: .1,
      AnimKey.cast: .1,
      AnimKey.teleportOut: .1,
      AnimKey.spawn: .1,
      AnimKey.ranged: .1,
      AnimKey.strike: .1,
      AnimKey.hit: .1,
      AnimKey.death: .1,
    },
  );
  static const orb = RenderAnimSetDefinition(
    frameWidth: 138,
    frameHeight: 93,
    anchorPoint: Vec2(69, 45),
    sourcesByKey: {
      AnimKey.spawn:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.idle:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
    },
    rowByKey: {AnimKey.spawn: 9, AnimKey.idle: 10, AnimKey.hit: 11},
    frameCountsByKey: {AnimKey.spawn: 3, AnimKey.idle: 8, AnimKey.hit: 6},
    stepTimeSecondsByKey: {
      AnimKey.spawn: .08,
      AnimKey.idle: .08,
      AnimKey.hit: .08,
    },
  );
  static const eruption = RenderAnimSetDefinition(
    frameWidth: 138,
    frameHeight: 93,
    anchorPoint: Vec2(69, 92),
    sourcesByKey: {
      AnimKey.hit:
          'entities/enemies/ancient_god_pack/voidborn_goddess/sprite_sheet.png',
    },
    rowByKey: {AnimKey.hit: 8},
    frameCountsByKey: {AnimKey.hit: 17},
    stepTimeSecondsByKey: {AnimKey.hit: .08},
  );
}
