import 'package:runner_core/abilities/ability_def.dart';

import 'tap_ability_control.dart';

/// Jump uses the shared tap control geometry in gameplay and authoring previews.
class JumpControl extends TapAbilityControl {
  const JumpControl({
    super.key,
    required super.onPressed,
    super.targetKey,
    super.enabled,
    super.affordable,
    super.tuning,
    super.resources,
    super.missing,
    super.onShortfall,
  }) : super(slot: AbilitySlot.jump);
}
