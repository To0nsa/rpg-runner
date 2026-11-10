import 'package:game_presentation/enemy_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';
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
                context.l10n.forestBlessingName,
            }
          : switch (arena!.phase) {
              BossArenaPhase.introduction => context.l10n.bossAwakens(
                enemy: enemyDisplayName(
                  arena.enemyId,
                  strings: context.gameL10n,
                ),
              ),
              BossArenaPhase.failed => context.l10n.bossEncounterEnded,
              _ => enemyDisplayName(arena.enemyId, strings: context.gameL10n),
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
                    ? context.l10n.bossHealthSemantics(
                        caption: caption,
                        health: arena!.hp100 ~/ 100,
                      )
                    : context.l10n.bossRestorationSemantics(
                        caption: caption,
                        percent: blessing.restorationBp ~/ 100,
                      ),
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
                          context.l10n.bossRestoration(
                            percent: blessing.restorationBp ~/ 100,
                          ),
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
