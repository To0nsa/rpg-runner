/// Player animation loading utilities (render layer only).
///
/// Loads horizontal sprite-strip animations from `assets/images/entities/player/`.
library;

import 'package:flame/cache.dart';

import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

Future<SpriteAnimSet> loadPlayerAnimations(
  Images images, {
  required RenderAnimSetDefinition renderAnim,
}) async {
  final oneShotKeys = <AnimKey>{
    AnimKey.strike,
    AnimKey.backStrike,
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

/// Run-owned animation definitions shared by live and ghost player views.
/// Images remain owned by the Flame image cache; views own their own tickers.
class PlayerAnimationLibrary {
  PlayerAnimationLibrary(this.images);

  final Images images;
  final Map<RenderAnimSetDefinition, Future<SpriteAnimSet>> _sets = {};

  /// Coalesces concurrent loads of the same catalog definition.
  Future<SpriteAnimSet> load(RenderAnimSetDefinition definition) =>
      _sets.putIfAbsent(
        definition,
        () => loadPlayerAnimations(images, renderAnim: definition),
      );

  /// Drops run-owned definitions without disposing shared source images.
  void clear() => _sets.clear();
}
