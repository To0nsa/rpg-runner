import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';
import 'spell_impact_id.dart';

const int _fireExplosionFrameWidth = 64;
const int _fireExplosionFrameHeight = 64;
const int _fireExplosionFrames = 16;
const int _fireExplosionGridColumns = 4;
const double _fireExplosionStepSeconds = 0.05;

const Map<AnimKey, String> _fireExplosionSourcesByKey = <AnimKey, String>{
  AnimKey.hit: 'entities/spells/fire/explosion/oneshot.png',
};

const Map<AnimKey, int> _fireExplosionFrameCountsByKey = <AnimKey, int>{
  AnimKey.hit: _fireExplosionFrames,
};

const Map<AnimKey, int> _fireExplosionGridColumnsByKey = <AnimKey, int>{
  AnimKey.hit: _fireExplosionGridColumns,
};

const Map<AnimKey, double> _fireExplosionStepTimeSecondsByKey =
    <AnimKey, double>{AnimKey.hit: _fireExplosionStepSeconds};

const RenderAnimSetDefinition _fireExplosionRenderAnim =
    RenderAnimSetDefinition(
      frameWidth: _fireExplosionFrameWidth,
      frameHeight: _fireExplosionFrameHeight,
      anchorPoint: Vec2(
        _fireExplosionFrameWidth * 0.5,
        _fireExplosionFrameHeight * 0.5,
      ),
      sourcesByKey: _fireExplosionSourcesByKey,
      frameCountsByKey: _fireExplosionFrameCountsByKey,
      gridColumnsByKey: _fireExplosionGridColumnsByKey,
      stepTimeSecondsByKey: _fireExplosionStepTimeSecondsByKey,
    );

/// Lookup table for spell-impact render animation definitions.
class SpellImpactRenderCatalog {
  const SpellImpactRenderCatalog();

  RenderAnimSetDefinition get(SpellImpactId id) {
    switch (id) {
      case SpellImpactId.unknown:
        throw ArgumentError.value(
          id,
          'id',
          'SpellImpactId.unknown has no render catalog entry.',
        );
      case SpellImpactId.fireExplosion:
        return _fireExplosionRenderAnim;
    }
  }
}
