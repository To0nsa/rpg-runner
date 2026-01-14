/// Unoco Demon sprite render component driven by Core snapshots.
library;

import 'package:flame/components.dart';

import '../sprite_anim/deterministic_anim_view_component.dart';
import '../sprite_anim/sprite_anim_set.dart';

class UnocoDemonViewComponent extends DeterministicAnimViewComponent {
  UnocoDemonViewComponent({
    required SpriteAnimSet animationSet,
    Vector2? renderSize,
    Vector2? renderScale,
  }) : super(
         animSet: animationSet,
         renderSize: renderSize ??
             Vector2(animationSet.frameSize.x, animationSet.frameSize.y),
         renderScale: renderScale,
       );
}
