import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

const _hunterShootSource = 'entities/player/bounty_hunter/effects/shoot.png';

/// Native shared effect cells; bomb pivots align the fuse and blast support line.
abstract final class BountyHunterProjectileRender {
  static const bomb = RenderAnimSetDefinition(
    frameWidth: 89,
    frameHeight: 65,
    anchorPoint: Vec2(34, 61),
    sourcesByKey: {
      AnimKey.idle: 'entities/player/bounty_hunter/gun/add_on_sheet.png',
      AnimKey.bombFuse: 'entities/player/bounty_hunter/gun/add_on_sheet.png',
      AnimKey.bombExplosion:
          'entities/player/bounty_hunter/gun/add_on_sheet.png',
    },
    rowByKey: {AnimKey.idle: 6, AnimKey.bombFuse: 7, AnimKey.bombExplosion: 4},
    frameCountsByKey: {
      AnimKey.idle: 3,
      AnimKey.bombFuse: 4,
      AnimKey.bombExplosion: 9,
    },
    stepTimeSecondsByKey: {
      AnimKey.idle: .10,
      AnimKey.bombFuse: .06,
      AnimKey.bombExplosion: .06,
    },
  );
  // Explicit constants also provide source bindings for the Entities editor.
  static const pistol = RenderAnimSetDefinition(
    frameWidth: 52,
    frameHeight: 38,
    anchorPoint: Vec2(26, 20),
    sourcesByKey: {
      AnimKey.idle: _hunterShootSource,
      AnimKey.hit: _hunterShootSource,
    },
    rowByKey: {AnimKey.idle: 0, AnimKey.hit: 1},
    frameCountsByKey: {AnimKey.idle: 3, AnimKey.hit: 4},
    stepTimeSecondsByKey: {AnimKey.idle: .06, AnimKey.hit: .06},
  );
  static const crossbow = RenderAnimSetDefinition(
    frameWidth: 52,
    frameHeight: 38,
    anchorPoint: Vec2(26, 20),
    sourcesByKey: {
      AnimKey.idle: _hunterShootSource,
      AnimKey.hit: _hunterShootSource,
    },
    rowByKey: {AnimKey.idle: 2, AnimKey.hit: 7},
    frameStartByKey: {AnimKey.hit: 1},
    frameCountsByKey: {AnimKey.idle: 4, AnimKey.hit: 5},
    stepTimeSecondsByKey: {AnimKey.idle: .06, AnimKey.hit: .06},
  );
  static const shotgun = RenderAnimSetDefinition(
    frameWidth: 52,
    frameHeight: 38,
    anchorPoint: Vec2(26, 20),
    sourcesByKey: {
      AnimKey.idle: _hunterShootSource,
      AnimKey.hit: _hunterShootSource,
    },
    rowByKey: {AnimKey.idle: 3, AnimKey.hit: 6},
    frameStartByKey: {AnimKey.hit: 1},
    frameCountsByKey: {AnimKey.idle: 3, AnimKey.hit: 5},
    stepTimeSecondsByKey: {AnimKey.idle: .06, AnimKey.hit: .06},
  );
}
