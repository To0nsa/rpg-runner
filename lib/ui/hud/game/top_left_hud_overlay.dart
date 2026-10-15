import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../game/game_controller.dart';
import '../../controls/control_resource_usage.dart';
import '../../theme/ui_hud_theme.dart';
import '../../theme/ui_tokens.dart';
import 'level_blessings_hud.dart';
import 'resource_bar.dart';

class TopLeftHudOverlay extends StatelessWidget {
  const TopLeftHudOverlay({
    required this.controller,
    this.active = true,
    this.compact = false,
    this.warningSignal,
    super.key,
  });

  final GameController controller;
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: ObjectKey(controller),
                padding: EdgeInsets.all(ui.space.xs),
                decoration: context.hudTheme.panelDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ResourceBar(
                      compact: compact,
                      resource: HudResource.health,
                      value: hud.hp,
                      maximum: hud.hpMax,
                      active: active,
                      warningSignal: warningSignal,
                    ),
                    SizedBox(height: ui.space.xxs / 2),
                    ResourceBar(
                      compact: compact,
                      resource: HudResource.mana,
                      value: hud.mana,
                      maximum: hud.manaMax,
                      active: active,
                      warningSignal: warningSignal,
                    ),
                    SizedBox(height: ui.space.xxs / 2),
                    ResourceBar(
                      compact: compact,
                      resource: HudResource.stamina,
                      value: hud.stamina,
                      maximum: hud.staminaMax,
                      active: active,
                      warningSignal: warningSignal,
                    ),
                  ],
                ),
              ),
              if (hud.blessings.isNotEmpty) ...[
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
