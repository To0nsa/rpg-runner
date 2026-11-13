import 'package:flutter/material.dart';
import 'package:runner_core/abilities/ability_def.dart';

import '../../l10n/app_localization.dart';
import '../../theme/ui_action_button_theme.dart';
import '../ability_slot_visual_spec.dart';
import '../action_button.dart';
import '../control_resource_usage.dart';
import '../controls_tuning.dart';
import '../layout/controls_radial_layout.dart';
import '../resource_action_feedback.dart';
import '../run_controls_tuning.dart';

/// A tap ability and its real radial anchor, shared by HUD and authoring.
class TapAbilityControl extends StatelessWidget {
  const TapAbilityControl({
    super.key,
    required this.onPressed,
    required this.slot,
    this.cooldownTicksLeft = 0,
    this.cooldownTicksTotal = 0,
    this.recastAvailable = false,
    this.targetKey,
    this.enabled = true,
    this.affordable = true,
    this.tuning = ControlsTuning.fixed,
    this.resources = ControlResourceUsage.none,
    this.missing = ControlResourceUsage.none,
    this.onShortfall,
  });

  final VoidCallback onPressed;
  final AbilitySlot slot;
  final int cooldownTicksLeft, cooldownTicksTotal;
  final bool recastAvailable;
  final Key? targetKey;
  final bool enabled, affordable;
  final ControlsTuning tuning;
  final ControlResourceUsage resources, missing;
  final ValueChanged<ControlResourceUsage>? onShortfall;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveRunControlsTuning(
      base: tuning,
      actionButtons: context.actionButtons,
    );
    final style = resolved.style;
    final layout = ControlsRadialLayoutSolver.solve(
      layout: resolved.layout,
      action: style.actionButton,
      directional: style.directionalActionButton,
    );
    final spec = abilityRadialLayoutSpec.slotSpec(slot);
    final anchor = abilityRadialLayoutSpec.anchorFor(
      layout: layout,
      slot: slot,
    );
    return Positioned(
      right: anchor.right,
      bottom: anchor.bottom,
      child: IgnorePointer(
        ignoring: !enabled,
        child: ResourceActionFeedback(
          missing: cooldownTicksLeft > 0 && !recastAvailable
              ? ControlResourceUsage.none
              : missing,
          onShortfall: onShortfall,
          child: ActionButton(
            key: targetKey,
            label: spec.label(context.l10n),
            icon: spec.icon,
            resources: resources,
            onPressed: onPressed,
            affordable: affordable,
            cooldownTicksLeft: cooldownTicksLeft,
            cooldownTicksTotal: cooldownTicksTotal,
            recastAvailable: recastAvailable,
            tuning: style.actionButton,
            cooldownRing: style.cooldownRing,
            size: abilityRadialLayoutSpec.sizeFor(layout: layout, slot: slot),
          ),
        ),
      ),
    );
  }
}
