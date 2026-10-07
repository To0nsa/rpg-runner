import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';
import 'spell_impact_id.dart';
import 'voidcaller_effect_catalog.dart';
import '../enemies/voidborn_goddess_render_catalog.dart';

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
      case SpellImpactId.goddessEruption:
        return VoidbornGoddessRenderCatalog.eruption;
      case SpellImpactId.voidVerticalBeam:
        return VoidcallerEffectCatalog.vertical;
      case SpellImpactId.voidDiagonalBeam:
        return VoidcallerEffectCatalog.diagonal;
      case SpellImpactId.deathPillar:
        return const RenderAnimSetDefinition(
          frameWidth: 140,
          frameHeight: 93,
          // Source-frame bottom lands on the captured terrain surface at any scale.
          anchorPoint: Vec2(70, 93),
          sourcesByKey: {
            AnimKey.hit: 'entities/enemies/bringer_of_death/sheet.png',
          },
          rowByKey: {AnimKey.hit: 6},
          gridColumnsByKey: {AnimKey.hit: 8},
          frameCountsByKey: {AnimKey.hit: 16},
          stepTimeSecondsByKey: {AnimKey.hit: .04},
        );
      case SpellImpactId.fireExplosion:
        return _fireExplosionRenderAnim;
      case SpellImpactId.holyBlessing:
        return const RenderAnimSetDefinition(
          frameWidth: 48,
          frameHeight: 48,
          anchorPoint: Vec2(24, 48),
          sourcesByKey: {AnimKey.hit: 'entities/effects/blessings/holy_02.png'},
          gridColumnsByKey: {AnimKey.hit: 16},
          frameCountsByKey: {AnimKey.hit: 16},
          stepTimeSecondsByKey: {AnimKey.hit: .05},
        );
    }
  }
}
