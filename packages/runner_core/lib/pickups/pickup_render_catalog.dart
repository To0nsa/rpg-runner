import '../contracts/render_anim_set_definition.dart';
import '../snapshots/entity_render_snapshot.dart';
import '../snapshots/enums.dart';
import '../util/vec2.dart';

const int _frameW = 16;
const int _frameH = 16;
const int _frames = 12;
const double _stepSeconds = 0.08;

const Map<AnimKey, int> _frameCountsByKey = <AnimKey, int>{
  AnimKey.idle: _frames,
};

const Map<AnimKey, double> _stepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: _stepSeconds,
};

RenderAnimSetDefinition _rowFromSheet({
  required String assetPath,
  required int row,
}) {
  return RenderAnimSetDefinition(
    frameWidth: _frameW,
    frameHeight: _frameH,
    anchorPoint: Vec2(_frameW * 0.5, _frameH * 0.5),
    sourcesByKey: <AnimKey, String>{AnimKey.idle: assetPath},
    frameCountsByKey: _frameCountsByKey,
    stepTimeSecondsByKey: _stepTimeSecondsByKey,
    rowByKey: <AnimKey, int>{AnimKey.idle: row},
  );
}

class PickupRenderCatalog {
  const PickupRenderCatalog();

  RenderAnimSetDefinition get(int pickupVariant) {
    switch (pickupVariant) {
      case PickupVariant.collectible:
        return const RenderAnimSetDefinition(
          frameWidth: 25,
          frameHeight: 25,
          anchorPoint: Vec2(12.5, 12.5),
          sourcesByKey: <AnimKey, String>{
            AnimKey.idle: 'entities/collectibles/gold_spin.png',
          },
          frameCountsByKey: <AnimKey, int>{AnimKey.idle: 7},
          // Match the asset pack's 100 ms per-frame spin preview.
          stepTimeSecondsByKey: <AnimKey, double>{AnimKey.idle: 0.1},
        );
      case PickupVariant.restorationHealth:
        return _rowFromSheet(
          assetPath: 'entities/regenerationItems/gems.png',
          row: 0,
        );
      case PickupVariant.restorationMana:
        return _rowFromSheet(
          assetPath: 'entities/regenerationItems/gems.png',
          row: 1,
        );
      case PickupVariant.restorationStamina:
        return _rowFromSheet(
          assetPath: 'entities/regenerationItems/gems.png',
          row: 2,
        );
      default:
        throw StateError(
          'No render animation defined for pickupVariant=$pickupVariant.',
        );
    }
  }
}
