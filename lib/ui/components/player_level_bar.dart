import 'package:flutter/material.dart';

import 'reward_value_paint.dart';
import '../state/ownership/player_progress.dart';
import '../theme/ui_tokens.dart';
import 'ui_progress_animator.dart';

/// Account level and progress toward the next level, derived from lifetime XP.
class PlayerLevelBar extends StatefulWidget {
  const PlayerLevelBar({
    super.key,
    required this.progress,
    this.animateFromTotalXp,
    this.rewardRevision,
  });

  final PlayerProgress progress;
  final int? rewardRevision;

  /// Starts a visual catch-up from this lifetime XP when the hub returns.
  /// The canonical [progress] remains the source of truth throughout.
  final int? animateFromTotalXp;

  @override
  State<PlayerLevelBar> createState() => _PlayerLevelBarState();
}

class _PlayerLevelBarState extends State<PlayerLevelBar>
    with SingleTickerProviderStateMixin {
  late final UiProgressAnimator _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimation = UiProgressAnimator(
      vsync: this,
      initialValue: widget.progress.totalXp,
    );
    final from = widget.animateFromTotalXp;
    if (from != null && from < _progressAnimation.target) {
      _progressAnimation.animateFrom(from, _progressAnimation.target);
    }
  }

  @override
  void didUpdateWidget(PlayerLevelBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.progress.totalXp;
    final from = widget.animateFromTotalXp;
    if (from != oldWidget.animateFromTotalXp && from != null) {
      _progressAnimation.animateFrom(from, target);
    } else if (target != oldWidget.progress.totalXp) {
      if (from != null && target > _progressAnimation.target) {
        _progressAnimation.animateFrom(_progressAnimation.value, target);
      } else {
        _progressAnimation.jumpTo(target);
      }
    }
  }

  @override
  void dispose() {
    _progressAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return AnimatedBuilder(
      animation: _progressAnimation.animation,
      builder: (context, _) {
        final displayed = PlayerProgress(
          totalXp: _progressAnimation.value,
          acceptedRuns: widget.progress.acceptedRuns,
          damageDealt100: widget.progress.damageDealt100,
          damageTaken100: widget.progress.damageTaken100,
        );
        final earned = displayed.xpInLevel;
        final needed = displayed.xpForNextLevel;
        return RewardValuePaint(
          revision: widget.rewardRevision,
          metric: 'xp',
          value: displayed.totalXp,
          target: widget.progress.totalXp,
          surface: 'hub',
          child: Semantics(
            label: widget.progress.isMaxLevel
                ? 'Level ${PlayerProgress.maxLevel}, maximum level reached'
                : 'Level ${widget.progress.level}, ${widget.progress.xpInLevel} of ${widget.progress.xpForNextLevel} XP to next level',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ui.radii.sm),
                    child: SizedBox(
                      height: 28,
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          ColoredBox(color: ui.colors.outline),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: displayed.isMaxLevel
                                  ? 1
                                  : earned / needed,
                              heightFactor: 1,
                              child: ColoredBox(color: ui.colors.accentStrong),
                            ),
                          ),
                          ColoredBox(
                            color: ui.colors.background.withValues(alpha: .35),
                          ),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ui.space.xxs,
                              ),
                              child: Text(
                                displayed.isMaxLevel
                                    ? 'LEVEL ${displayed.level}  ·  MAX LEVEL'
                                    : 'LEVEL ${displayed.level}  ·  $earned / $needed XP',
                                style: ui.text.label.copyWith(
                                  color: ui.colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
