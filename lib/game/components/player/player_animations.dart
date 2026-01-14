/// Player animation loading utilities (render layer only).
///
/// Loads horizontal sprite-strip animations from `assets/images/entities/player/`.
library;

import 'package:flame/cache.dart';

import '../../../core/snapshots/enums.dart';
import '../../../core/players/player_character_definition.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

Future<SpriteAnimSet> loadPlayerAnimations(
  Images images, {
  required PlayerRenderAnimSetDefinition renderAnim,
}) async {
  final oneShotKeys = <AnimKey>{
    AnimKey.attack,
    AnimKey.attackLeft,
    AnimKey.cast,
    AnimKey.ranged,
    AnimKey.dash,
    AnimKey.hit,
    AnimKey.death,
  };
  final animSet = await loadStripAnimations(
    images,
    frameWidth: renderAnim.frameWidth,
    frameHeight: renderAnim.frameHeight,
    sourcesByKey: renderAnim.sourcesByKey,
    frameCountsByKey: renderAnim.frameCountsByKey,
    stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
    oneShotKeys: oneShotKeys,
  );

  // No dedicated spawn strip yet; map to idle for now.
  animSet.animations[AnimKey.spawn] ??= animSet.animations[AnimKey.idle]!;

  return animSet;
}
