import 'package:flutter/material.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';

/// Encounter feedback reads Core; the entrance never depends on widget timers.
class BossArenaHud extends StatelessWidget {
  const BossArenaHud({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final arena = controller.snapshot.bossArena;
      if (arena == null) return const SizedBox.shrink();
      final ui = context.ui;
      final caption = switch (arena.phase) {
        BossArenaPhase.introduction => 'Bringer of Death awakens',
        BossArenaPhase.defeated => 'Boss defeated · exit opening',
        BossArenaPhase.failed => 'Encounter ended',
        _ => 'Bringer of Death',
      };
      return IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 46),
            child: Semantics(
              label: '$caption, ${arena.hp100 ~/ 100} health',
              child: Container(
                width: 220,
                padding: EdgeInsets.all(ui.space.xs),
                decoration: BoxDecoration(
                  color: ui.colors.shadow.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(ui.radii.sm),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: ui.text.body.copyWith(
                        color: ui.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: ui.space.xxs),
                    LinearProgressIndicator(
                      value: (arena.hp100 / arena.hpMax100).clamp(0, 1),
                      color: const Color(0xFFB886E8),
                      backgroundColor: const Color(0xFF34243E),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
