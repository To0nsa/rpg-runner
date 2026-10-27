import 'package:flutter/material.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/boss_victory_blessing_snapshot.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_hud_theme.dart';
import '../../components/hud_frame.dart';

/// Encounter feedback reads Core; the entrance never depends on widget timers.
class BossArenaHud extends StatelessWidget {
  const BossArenaHud({super.key, required this.controller, this.panelKey});
  final GameController controller;

  /// Tight painted panel bounds for other HUD elements to avoid after layout.
  final GlobalKey? panelKey;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final arena = controller.snapshot.bossArena;
      final blessing = controller.snapshot.bossVictoryBlessing;
      if (arena == null && blessing == null) return const SizedBox.shrink();
      if (arena?.phase == BossArenaPhase.defeated && blessing == null) {
        return const SizedBox.shrink();
      }
      final ui = context.ui;
      final caption = blessing != null
          ? switch (blessing.id) {
              BossVictoryBlessingId.forestLadies =>
                'Bénédiction des Dames de la forêt',
            }
          : switch (arena!.phase) {
              BossArenaPhase.introduction =>
                '${arena.enemyId.displayName} awakens',
              BossArenaPhase.failed => 'Encounter ended',
              _ => arena.enemyId.displayName,
            };
      return IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              // Tuck under the timer; narrow screens still need to clear vitals.
              padding: EdgeInsets.only(
                top: constraints.maxWidth < 640 ? 82 : 54,
              ),
              child: Semantics(
                label: blessing == null
                    ? '$caption, ${arena!.hp100 ~/ 100} health'
                    : '$caption, ${blessing.restorationBp ~/ 100} percent health, mana and stamina restored',
                child: HudPanel(
                  key: panelKey,
                  width: 220,
                  padding: EdgeInsets.all(ui.space.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: ui.text.body.copyWith(
                          color: context.hudTheme.foreground,
                        ),
                      ),
                      SizedBox(height: ui.space.xxs),
                      if (blessing != null)
                        Text(
                          '+${blessing.restorationBp ~/ 100} % santé · mana · endurance',
                          textAlign: TextAlign.center,
                          style: ui.text.body.copyWith(
                            color: context.hudTheme.highlight,
                          ),
                        )
                      else
                        LinearProgressIndicator(
                          value: (arena!.hp100 / arena.hpMax100).clamp(0, 1),
                          color: context.hudTheme.foreground,
                          backgroundColor: context.hudTheme.track,
                          minHeight: 6,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
