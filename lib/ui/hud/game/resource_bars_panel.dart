import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../components/hud_frame.dart';
import '../../controls/control_resource_usage.dart';
import '../../theme/ui_tokens.dart';
import 'resource_bar.dart';

/// Shared live/authoring resource panel. Values are resource units, not fixed-point.
class ResourceBarsPanel extends StatelessWidget {
  const ResourceBarsPanel({
    super.key,
    required this.health,
    required this.healthMax,
    required this.ability,
    required this.abilityMax,
    required this.stamina,
    required this.staminaMax,
    this.abilityResource = HudResource.mana,
    this.active = true,
    this.compact = false,
    this.warningSignal,
  });

  final double health, healthMax, ability, abilityMax, stamina, staminaMax;
  final HudResource abilityResource;
  final bool active, compact;
  final ValueListenable<ControlResourceUsage>? warningSignal;

  @override
  Widget build(BuildContext context) => HudPanel(
    padding: EdgeInsets.all(context.ui.space.xs),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResourceBar(
          resource: HudResource.health,
          value: health,
          maximum: healthMax,
          active: active,
          compact: compact,
          warningSignal: warningSignal,
        ),
        SizedBox(height: context.ui.space.xxs / 2),
        ResourceBar(
          resource: abilityResource,
          value: ability,
          maximum: abilityMax,
          active: active,
          compact: compact,
          warningSignal: warningSignal,
        ),
        SizedBox(height: context.ui.space.xxs / 2),
        ResourceBar(
          resource: HudResource.stamina,
          value: stamina,
          maximum: staminaMax,
          active: active,
          compact: compact,
          warningSignal: warningSignal,
        ),
      ],
    ),
  );
}
