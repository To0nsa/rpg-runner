/// Player animation loading utilities (render layer only).
///
/// Loads horizontal sprite-strip animations from `assets/images/entities/player/`.
library;

import 'package:flame/cache.dart';

import '../../../core/contracts/render_anim_set_definition.dart';
import '../../../core/snapshots/enums.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

Future<SpriteAnimSet> loadPlayerAnimations(
  Images images, {
  required RenderAnimSetDefinition renderAnim,
}) async {
  final oneShotKeys = <AnimKey>{
    AnimKey.strike,
    AnimKey.strikeBack,
    AnimKey.cast,
    AnimKey.ranged,
    AnimKey.dash,
    AnimKey.hit,
    AnimKey.death,
  };
  return loadAnimSetFromDefinition(
    images,
    renderAnim: renderAnim,
    oneShotKeys: oneShotKeys,
  );
}
