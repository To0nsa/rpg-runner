import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../../../game/game_controller.dart';
import '../../controls/control_resource_usage.dart';
import 'resource_bars_panel.dart';
import '../../theme/ui_tokens.dart';
import 'level_blessings_hud.dart';
import 'resource_bar.dart';
import 'riposte_hud.dart';

class TopLeftHudOverlay extends StatelessWidget {
  const TopLeftHudOverlay({
    required this.controller,
    this.active = true,
    this.compact = false,
    this.warningSignal,
    this.resourcesTargetKey,
    this.blessingResourcesTargetKey,
    this.showBlessings = true,
    super.key,
  });

  final GameController controller;
  final Key? resourcesTargetKey, blessingResourcesTargetKey;
  final bool showBlessings;
  final bool active;
  final bool compact;
  final ValueListenable<ControlResourceUsage>? warningSignal;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final hud = controller.snapshot.hud;
      final ui = context.ui;
      return IgnorePointer(
        child: RepaintBoundary(
          child: Column(
            key: blessingResourcesTargetKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Keep the measured target stable while resetting bar animation state
              // when the host replaces the attempt's controller.
              KeyedSubtree(
                key: resourcesTargetKey,
                child: ResourceBarsPanel(
                  key: ObjectKey(controller),
                  health: hud.hp,
                  healthMax: hud.hpMax,
                  ability: hud.mana,
                  abilityMax: hud.manaMax,
                  stamina: hud.stamina,
                  staminaMax: hud.staminaMax,
                  abilityResource:
                      controller.playerCharacter.id ==
                          PlayerCharacterId.bountyHunter
                      ? HudResource.supplies
                      : HudResource.mana,
                  active: active,
                  compact: compact,
                  warningSignal: warningSignal,
                ),
              ),
              if (active && hud.riposteTicksLeft > 0) ...[
                SizedBox(height: ui.space.xxs),
                RiposteHud(
                  ticksLeft: hud.riposteTicksLeft,
                  guarding: hud.riposteGuarding,
                  tickHz: controller.tickHz,
                ),
              ],
              if (showBlessings && hud.blessings.isNotEmpty) ...[
                SizedBox(height: ui.space.xxs),
                LevelBlessingsHud(
                  blessings: hud.blessings,
                  tick: controller.tick,
                  tickHz: controller.tickHz,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
