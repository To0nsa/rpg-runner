import 'package:flutter/material.dart';

import '../../../components/progress_meter.dart';
import '../../../l10n/app_localization.dart';
import '../../../theme/ui_hub_theme.dart';
import '../../../theme/ui_tokens.dart';

/// Weekly details and compact actions using the Bestiary's filled Open treatment.
class WeeklyBadgeRow extends StatelessWidget {
  const WeeklyBadgeRow({
    super.key,
    required this.title,
    required this.isWeeklyLoading,
    required this.onWeeklyPressed,
    required this.onWeeklyLeaderboardPressed,
    this.levelName,
    this.practiceOnly = false,
  });

  final String title;
  final String? levelName;
  final bool isWeeklyLoading, practiceOnly;
  final VoidCallback? onWeeklyPressed, onWeeklyLeaderboardPressed;

  @override
  Widget build(BuildContext context) {
    final hub = context.hub;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: practiceOnly ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: hub.surface,
        border: Border.all(color: hub.outline),
        borderRadius: BorderRadius.circular(context.ui.radii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  practiceOnly ? context.l10n.hubLocalPractice : title,
                  style: hub.detail,
                  textAlign: TextAlign.center,
                ),
                if (!practiceOnly && levelName != null)
                  Text(
                    levelName!,
                    style: context.ui.text.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          if (!practiceOnly) ...[
            const SizedBox(width: 8),
            _WeeklyAction(
              key: const ValueKey('weekly-play'),
              label: context.l10n.hubWeeklyPlay,
              onPressed: isWeeklyLoading ? null : onWeeklyPressed,
            ),
            const SizedBox(width: 8),
            _WeeklyAction(
              key: const ValueKey('weekly-leaderboard'),
              label: context.l10n.uiLeaderboard,
              onPressed: onWeeklyLeaderboardPressed,
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyAction extends StatelessWidget {
  const _WeeklyAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: ui.sizes.tapTarget,
            minHeight: ui.sizes.tapTarget,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: onPressed == null ? .5 : 1,
                child: ProgressMeter(fraction: 1, label: label),
              ),
              // Keep the compact fill inside a full-size touch/focus target.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onPressed,
                    canRequestFocus: onPressed != null,
                    excludeFromSemantics: true,
                    borderRadius: BorderRadius.circular(ui.radii.sm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
