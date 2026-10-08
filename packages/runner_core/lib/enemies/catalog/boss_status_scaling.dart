import '../../ecs/stores/combat/status_scaling_store.dart';

/// Half-strength boss debuffs preserve their authored duration (5000 basis points).
const bossStatusScaling = StatusScalingDef(
  defaultDebuff: StatusEffectScaling(magnitudeScaleBp: 5000),
);
