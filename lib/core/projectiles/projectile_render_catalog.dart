import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import 'projectile_id.dart';

// -----------------------------------------------------------------------------
// Ice Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _iceBoltFrameWidth = 48;
const int _iceBoltFrameHeight = 32;

const int _iceBoltStartFrames = 3;
const int _iceBoltRepeatFrames = 10;
const int _iceBoltHitFrames = 8;

const double _iceBoltStartStepSeconds = 0.05;
const double _iceBoltRepeatStepSeconds = 0.06;
const double _iceBoltHitStepSeconds = 0.05;

const Map<AnimKey, int> _iceBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _iceBoltStartFrames,
  AnimKey.idle: _iceBoltRepeatFrames,
  AnimKey.hit: _iceBoltHitFrames,
};

const Map<AnimKey, double> _iceBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _iceBoltStartStepSeconds,
  AnimKey.idle: _iceBoltRepeatStepSeconds,
  AnimKey.hit: _iceBoltHitStepSeconds,
};

const Map<AnimKey, String> _iceBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/iceBolt/start.png',
  AnimKey.idle: 'entities/spells/iceBolt/repeatable.png',
  AnimKey.hit: 'entities/spells/iceBolt/hit.png',
};

const RenderAnimSetDefinition _iceBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _iceBoltFrameWidth,
  frameHeight: _iceBoltFrameHeight,
  sourcesByKey: _iceBoltSourcesByKey,
  frameCountsByKey: _iceBoltFrameCountsByKey,
  stepTimeSecondsByKey: _iceBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Thunder Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _thunderBoltFrameWidth = 32;
const int _thunderBoltFrameHeight = 32;

const int _thunderBoltStartFrames = 5;
const int _thunderBoltRepeatFrames = 5;
const int _thunderBoltHitFrames = 6;

const double _thunderBoltStartStepSeconds = 0.05;
const double _thunderBoltRepeatStepSeconds = 0.06;
const double _thunderBoltHitStepSeconds = 0.05;

const Map<AnimKey, int> _thunderBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _thunderBoltStartFrames,
  AnimKey.idle: _thunderBoltRepeatFrames,
  AnimKey.hit: _thunderBoltHitFrames,
};

const Map<AnimKey, double> _thunderBoltStepTimeSecondsByKey =
    <AnimKey, double>{
  AnimKey.spawn: _thunderBoltStartStepSeconds,
  AnimKey.idle: _thunderBoltRepeatStepSeconds,
  AnimKey.hit: _thunderBoltHitStepSeconds,
};

const Map<AnimKey, String> _thunderBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/thunderBolt/start.png',
  AnimKey.idle: 'entities/spells/thunderBolt/repeatable.png',
  AnimKey.hit: 'entities/spells/thunderBolt/hit.png',
};

const RenderAnimSetDefinition _thunderBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _thunderBoltFrameWidth,
  frameHeight: _thunderBoltFrameHeight,
  sourcesByKey: _thunderBoltSourcesByKey,
  frameCountsByKey: _thunderBoltFrameCountsByKey,
  stepTimeSecondsByKey: _thunderBoltStepTimeSecondsByKey,
);

/// Lookup table for projectile render animation definitions.
///
/// Core owns the animation timing and frame metadata. The renderer uses this
/// catalog to load assets and drive deterministic animation frames.
class ProjectileRenderCatalog {
  const ProjectileRenderCatalog();

  RenderAnimSetDefinition get(ProjectileId id) {
    switch (id) {
      case ProjectileId.iceBolt:
        return _iceBoltRenderAnim;
      case ProjectileId.thunderBolt:
        return _thunderBoltRenderAnim;
      case ProjectileId.arrow:
      case ProjectileId.throwingAxe:
        throw StateError('No render animation defined for $id.');
    }
  }
}
