/// Player render component driven purely by Core snapshots.
library;

import 'package:flame/components.dart';

import '../../../core/snapshots/enums.dart';
import '../sprite_anim/deterministic_anim_view_component.dart';
import '../sprite_anim/sprite_anim_set.dart';

class PlayerViewComponent extends DeterministicAnimViewComponent {
  PlayerViewComponent({
    required SpriteAnimSet animationSet,
    Vector2? renderSize,
    super.renderScale,
    super.feedbackTuning,
  }) : super(
         animSet: animationSet,
         initial: AnimKey.idle,
         renderSize:
             renderSize ??
             Vector2(animationSet.frameSize.x, animationSet.frameSize.y),
         fallbackResolver: (desired) {
           // Allow directional variants to fall back to their base animation key.
           if (desired == AnimKey.backStrike &&
               !animationSet.animations.containsKey(AnimKey.backStrike) &&
               animationSet.animations.containsKey(AnimKey.strike)) {
             return AnimKey.strike;
           }
           if (desired == AnimKey.ranged &&
               !animationSet.animations.containsKey(AnimKey.ranged) &&
               animationSet.animations.containsKey(AnimKey.cast)) {
             return AnimKey.cast;
           }
           return desired;
         },
       );
}
