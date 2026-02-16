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

const double _iceBoltStartStepSeconds = 0.06;
const double _iceBoltRepeatStepSeconds = 0.06;
const double _iceBoltHitStepSeconds = 0.06;

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
  AnimKey.spawn: 'entities/spells/ice/bolt/start.png',
  AnimKey.idle: 'entities/spells/ice/bolt/repeatable.png',
  AnimKey.hit: 'entities/spells/ice/bolt/hit.png',
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

const double _thunderBoltStartStepSeconds = 0.06;
const double _thunderBoltRepeatStepSeconds = 0.06;
const double _thunderBoltHitStepSeconds = 0.06;

const Map<AnimKey, int> _thunderBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _thunderBoltStartFrames,
  AnimKey.idle: _thunderBoltRepeatFrames,
  AnimKey.hit: _thunderBoltHitFrames,
};

const Map<AnimKey, double> _thunderBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _thunderBoltStartStepSeconds,
  AnimKey.idle: _thunderBoltRepeatStepSeconds,
  AnimKey.hit: _thunderBoltHitStepSeconds,
};

const Map<AnimKey, String> _thunderBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/thunder/bolt/start.png',
  AnimKey.idle: 'entities/spells/thunder/bolt/repeatable.png',
  AnimKey.hit: 'entities/spells/thunder/bolt/hit.png',
};

const RenderAnimSetDefinition _thunderBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _thunderBoltFrameWidth,
  frameHeight: _thunderBoltFrameHeight,
  sourcesByKey: _thunderBoltSourcesByKey,
  frameCountsByKey: _thunderBoltFrameCountsByKey,
  stepTimeSecondsByKey: _thunderBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Fire Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _fireBoltFrameWidth = 48;
const int _fireBoltFrameHeight = 48;

const int _fireBoltStartFrames = 4;
const int _fireBoltHitFrames = 6;

const double _fireBoltStartStepSeconds = 0.06;
const double _fireBoltIdleStepSeconds = 0.06;
const double _fireBoltHitStepSeconds = 0.06;

const Map<AnimKey, int> _fireBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _fireBoltStartFrames,
  AnimKey.idle: _fireBoltStartFrames,
  AnimKey.hit: _fireBoltHitFrames,
};

const Map<AnimKey, int> _fireBoltFrameStartByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 0,
  AnimKey.hit: 5,
};

const Map<AnimKey, double> _fireBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _fireBoltStartStepSeconds,
  AnimKey.idle: _fireBoltIdleStepSeconds,
  AnimKey.hit: _fireBoltHitStepSeconds,
};

const Map<AnimKey, String> _fireBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/fire/bolt/spriteSheet.png',
  AnimKey.idle: 'entities/spells/fire/bolt/spriteSheet.png',
  AnimKey.hit: 'entities/spells/fire/bolt/spriteSheet.png',
};

const RenderAnimSetDefinition _fireBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _fireBoltFrameWidth,
  frameHeight: _fireBoltFrameHeight,
  sourcesByKey: _fireBoltSourcesByKey,
  frameStartByKey: _fireBoltFrameStartByKey,
  frameCountsByKey: _fireBoltFrameCountsByKey,
  stepTimeSecondsByKey: _fireBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Acid Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _acidBoltFrameWidth = 32;
const int _acidBoltFrameHeight = 32;

const int _acidBoltStartFrames = 10;
const int _acidBoltHitFrames = 6;

const double _acidBoltStartStepSeconds = 0.06;
const double _acidBoltIdleStepSeconds = 0.06;
const double _acidBoltHitStepSeconds = 0.06;

const Map<AnimKey, int> _acidBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _acidBoltStartFrames,
  AnimKey.idle: _acidBoltStartFrames,
  AnimKey.hit: _acidBoltHitFrames,
};

const Map<AnimKey, int> _acidBoltFrameStartByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 0,
  AnimKey.hit: 10,
};

const Map<AnimKey, double> _acidBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _acidBoltStartStepSeconds,
  AnimKey.idle: _acidBoltIdleStepSeconds,
  AnimKey.hit: _acidBoltHitStepSeconds,
};

const Map<AnimKey, String> _acidBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/acid/bolt/spriteSheet.png',
  AnimKey.idle: 'entities/spells/acid/bolt/spriteSheet.png',
  AnimKey.hit: 'entities/spells/acid/bolt/spriteSheet.png',
};

const RenderAnimSetDefinition _acidBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _acidBoltFrameWidth,
  frameHeight: _acidBoltFrameHeight,
  sourcesByKey: _acidBoltSourcesByKey,
  frameStartByKey: _acidBoltFrameStartByKey,
  frameCountsByKey: _acidBoltFrameCountsByKey,
  stepTimeSecondsByKey: _acidBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Dark Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _darkBoltFrameWidth = 40;
const int _darkBoltFrameHeight = 32;

const int _darkBoltStartFrames = 10;
const int _darkBoltIdleFrames = 10;
const int _darkBoltHitFrames = 6;

const double _darkBoltStartStepSeconds = 0.06;
const double _darkBoltIdleStepSeconds = 0.06;
const double _darkBoltHitStepSeconds = 0.06;

const Map<AnimKey, int> _darkBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _darkBoltStartFrames,
  AnimKey.idle: _darkBoltIdleFrames,
  AnimKey.hit: _darkBoltHitFrames,
};

const Map<AnimKey, int> _darkBoltRowByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 0,
  AnimKey.hit: 1,
};

const Map<AnimKey, double> _darkBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _darkBoltStartStepSeconds,
  AnimKey.idle: _darkBoltIdleStepSeconds,
  AnimKey.hit: _darkBoltHitStepSeconds,
};

const Map<AnimKey, String> _darkBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/dark/bolt/spriteSheet.png',
  AnimKey.idle: 'entities/spells/dark/bolt/spriteSheet.png',
  AnimKey.hit: 'entities/spells/dark/bolt/spriteSheet.png',
};

const RenderAnimSetDefinition _darkBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _darkBoltFrameWidth,
  frameHeight: _darkBoltFrameHeight,
  sourcesByKey: _darkBoltSourcesByKey,
  rowByKey: _darkBoltRowByKey,
  frameCountsByKey: _darkBoltFrameCountsByKey,
  stepTimeSecondsByKey: _darkBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Earth Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _earthBoltFrameWidth = 48;
const int _earthBoltFrameHeight = 32;

const int _earthBoltStartFrames = 6;
const int _earthBoltIdleFrames = 6;
const int _earthBoltHitFrames = 4;

const double _earthBoltStartStepSeconds = 0.06;
const double _earthBoltIdleStepSeconds = 0.06;
const double _earthBoltHitStepSeconds = 0.06;

const Map<AnimKey, int> _earthBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _earthBoltStartFrames,
  AnimKey.idle: _earthBoltIdleFrames,
  AnimKey.hit: _earthBoltHitFrames,
};

const Map<AnimKey, int> _earthBoltRowByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 0,
  AnimKey.hit: 1,
};

const Map<AnimKey, double> _earthBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _earthBoltStartStepSeconds,
  AnimKey.idle: _earthBoltIdleStepSeconds,
  AnimKey.hit: _earthBoltHitStepSeconds,
};

const Map<AnimKey, String> _earthBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/earth/bolt/spriteSheet.png',
  AnimKey.idle: 'entities/spells/earth/bolt/spriteSheet.png',
  AnimKey.hit: 'entities/spells/earth/bolt/spriteSheet.png',
};

const RenderAnimSetDefinition _earthBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _earthBoltFrameWidth,
  frameHeight: _earthBoltFrameHeight,
  sourcesByKey: _earthBoltSourcesByKey,
  rowByKey: _earthBoltRowByKey,
  frameCountsByKey: _earthBoltFrameCountsByKey,
  stepTimeSecondsByKey: _earthBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Holy Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _holyBoltFrameWidth = 48;
const int _holyBoltFrameHeight = 32;

const int _holyBoltStartFrames = 2;
const int _holyBoltIdleFrames = 8;
const int _holyBoltHitFrames = 6;

const double _holyBoltStartStepSeconds = 0.06;
const double _holyBoltIdleStepSeconds = 0.06;
const double _holyBoltHitStepSeconds = 0.06;

const Map<AnimKey, int> _holyBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _holyBoltStartFrames,
  AnimKey.idle: _holyBoltIdleFrames,
  AnimKey.hit: _holyBoltHitFrames,
};

const Map<AnimKey, double> _holyBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _holyBoltStartStepSeconds,
  AnimKey.idle: _holyBoltIdleStepSeconds,
  AnimKey.hit: _holyBoltHitStepSeconds,
};

const Map<AnimKey, String> _holyBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/holy/bolt/start.png',
  AnimKey.idle: 'entities/spells/holy/bolt/repeatable.png',
  AnimKey.hit: 'entities/spells/holy/bolt/hit.png',
};

const RenderAnimSetDefinition _holyBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _holyBoltFrameWidth,
  frameHeight: _holyBoltFrameHeight,
  sourcesByKey: _holyBoltSourcesByKey,
  frameCountsByKey: _holyBoltFrameCountsByKey,
  stepTimeSecondsByKey: _holyBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Water Bolt render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _waterBoltFrameWidth = 64;
const int _waterBoltFrameHeight = 64;

const int _waterBoltSpawnFrames = 5;
const int _waterBoltIdleFrames = 16;
const int _waterBoltHitFrames = 15;

const double _waterBoltSpawnStepSeconds = 0.01;
const double _waterBoltIdleStepSeconds = 0.03;
const double _waterBoltHitStepSeconds = 0.03;

const Map<AnimKey, int> _waterBoltFrameCountsByKey = <AnimKey, int>{
  AnimKey.spawn: _waterBoltSpawnFrames,
  AnimKey.idle: _waterBoltIdleFrames,
  AnimKey.hit: _waterBoltHitFrames,
};

const Map<AnimKey, int> _waterBoltRowByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 1,
  AnimKey.hit: 0,
};

const Map<AnimKey, int> _waterBoltFrameStartByKey = <AnimKey, int>{
  AnimKey.spawn: 0,
  AnimKey.idle: 0,
  AnimKey.hit: 0,
};

const Map<AnimKey, int> _waterBoltGridColumnsByKey = <AnimKey, int>{
  AnimKey.spawn: 5,
  AnimKey.idle: 5,
  AnimKey.hit: 4,
};

const Map<AnimKey, double> _waterBoltStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.spawn: _waterBoltSpawnStepSeconds,
  AnimKey.idle: _waterBoltIdleStepSeconds,
  AnimKey.hit: _waterBoltHitStepSeconds,
};

const Map<AnimKey, String> _waterBoltSourcesByKey = <AnimKey, String>{
  AnimKey.spawn: 'entities/spells/water/bolt/start_and_repeatable.png',
  AnimKey.idle: 'entities/spells/water/bolt/start_and_repeatable.png',
  AnimKey.hit: 'entities/spells/water/bolt/hit.png',
};

const RenderAnimSetDefinition _waterBoltRenderAnim = RenderAnimSetDefinition(
  frameWidth: _waterBoltFrameWidth,
  frameHeight: _waterBoltFrameHeight,
  sourcesByKey: _waterBoltSourcesByKey,
  rowByKey: _waterBoltRowByKey,
  frameStartByKey: _waterBoltFrameStartByKey,
  gridColumnsByKey: _waterBoltGridColumnsByKey,
  frameCountsByKey: _waterBoltFrameCountsByKey,
  stepTimeSecondsByKey: _waterBoltStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Throwing Axe render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _throwingAxeFrameWidth = 32;
const int _throwingAxeFrameHeight = 32;

const int _throwingAxeFrames = 1;
const double _throwingAxeStepSeconds = 0.10;

const Map<AnimKey, int> _throwingAxeFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _throwingAxeFrames,
};

const Map<AnimKey, double> _throwingAxeStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _throwingAxeStepSeconds,
};

const Map<AnimKey, String> _throwingAxeSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'weapons/throwingWeapons/throwingAxe.png',
};

const RenderAnimSetDefinition _throwingAxeRenderAnim = RenderAnimSetDefinition(
  frameWidth: _throwingAxeFrameWidth,
  frameHeight: _throwingAxeFrameHeight,
  sourcesByKey: _throwingAxeSourcesByKey,
  frameCountsByKey: _throwingAxeFrameCountsByKey,
  stepTimeSecondsByKey: _throwingAxeStepTimeSecondsByKey,
);

// -----------------------------------------------------------------------------
// Throwing Axe render animation strip definitions (authoring-time)
// -----------------------------------------------------------------------------

const int _throwingKnifeFrameWidth = 32;
const int _throwingKnifeFrameHeight = 32;

const int _throwingKnifeFrames = 1;
const double _throwingKnifeStepSeconds = 0.10;

const Map<AnimKey, int> _throwingKnifeFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _throwingKnifeFrames,
};

const Map<AnimKey, double> _throwingKnifeStepTimeSecondsByKey =
    <AnimKey, double>{AnimKey.idle: _throwingKnifeStepSeconds};

const Map<AnimKey, String> _throwingKnifeSourcesByKey = <AnimKey, String>{
  AnimKey.idle: 'weapons/throwingWeapons/throwingKnife.png',
};

const RenderAnimSetDefinition _throwingKnifeRenderAnim =
    RenderAnimSetDefinition(
      frameWidth: _throwingKnifeFrameWidth,
      frameHeight: _throwingKnifeFrameHeight,
      sourcesByKey: _throwingKnifeSourcesByKey,
      frameCountsByKey: _throwingKnifeFrameCountsByKey,
      stepTimeSecondsByKey: _throwingKnifeStepTimeSecondsByKey,
    );

/// Lookup table for projectile render animation definitions.
///
/// Core owns the animation timing and frame metadata. The renderer uses this
/// catalog to load assets and drive deterministic animation frames.
class ProjectileRenderCatalog {
  const ProjectileRenderCatalog();

  RenderAnimSetDefinition get(ProjectileId id) {
    switch (id) {
      case ProjectileId.unknown:
        throw ArgumentError.value(
          id,
          'id',
          'ProjectileId.unknown has no render catalog entry.',
        );
      case ProjectileId.iceBolt:
        return _iceBoltRenderAnim;
      case ProjectileId.thunderBolt:
        return _thunderBoltRenderAnim;
      case ProjectileId.fireBolt:
        return _fireBoltRenderAnim;
      case ProjectileId.acidBolt:
        return _acidBoltRenderAnim;
      case ProjectileId.darkBolt:
        return _darkBoltRenderAnim;
      case ProjectileId.earthBolt:
        return _earthBoltRenderAnim;
      case ProjectileId.holyBolt:
        return _holyBoltRenderAnim;
      case ProjectileId.waterBolt:
        return _waterBoltRenderAnim;
      case ProjectileId.throwingAxe:
        return _throwingAxeRenderAnim;
      case ProjectileId.throwingKnife:
        return _throwingKnifeRenderAnim;
    }
  }
}
