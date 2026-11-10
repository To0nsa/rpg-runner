import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:flutter/material.dart';

import 'package:runner_core/abilities/ability_def.dart';

import '../../../components/app_button.dart';

import 'package:game_presentation/game_icon.dart';
import 'package:game_presentation/ability_text.dart';

import '../../../text/ability_tooltip_builder.dart';
import '../../../text/semantic_text.dart';
import '../../../theme/ui_tokens.dart';
import '../ability/ability_picker_presenter.dart';

class SkillsDetailsPane extends StatelessWidget {
  const SkillsDetailsPane({
    super.key,
    required this.selectedCandidate,
    required this.tooltip,
    required this.onFindInTown,
  });

  final AbilityPickerCandidate? selectedCandidate;
  final AbilityTooltip? tooltip;
  final VoidCallback onFindInTown;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _AbilityDetailsPane(
        selectedCandidate: selectedCandidate,
        tooltip: tooltip,
        onFindInTown: onFindInTown,
      ),
    );
  }
}

class _AbilityDetailsPane extends StatelessWidget {
  const _AbilityDetailsPane({
    required this.selectedCandidate,
    required this.tooltip,
    required this.onFindInTown,
  });

  final AbilityPickerCandidate? selectedCandidate;
  final AbilityTooltip? tooltip;
  final VoidCallback onFindInTown;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.4)),
        boxShadow: ui.shadows.card,
      ),
      padding: EdgeInsets.all(ui.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCandidate == null) ...[
            Text(
              context.l10n.uiNoAbilityAvailableForThisSlot,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
          ] else if (!selectedCandidate!.isOwned) ...[
            _LockedAbilityDetailsPane(
              abilityId: selectedCandidate!.id,
              onFindInTown: onFindInTown,
            ),
          ] else if (tooltip == null) ...[
            Text(
              context.l10n.uiNoAbilityDetailsAvailableRightNow,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
          ] else ...[
            Text(
              tooltip!.title,
              style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
            ),
            SizedBox(height: ui.space.xxs),
            Container(
              height: 1,
              color: ui.colors.outline.withValues(alpha: 0.35),
            ),
            if (tooltip!.cooldownSeconds != null) ...[
              SizedBox(height: ui.space.xxs),
              _DetailsMetricLine(
                label: context.l10n.uiCooldown,
                value: context.gameL10n.durationSeconds(
                  seconds: (tooltip!.cooldownSeconds! * 10).round() / 10,
                ),
              ),
            ],
            if (tooltip!.costLines.isNotEmpty) ...[
              for (final costLine in tooltip!.costLines) ...[
                SizedBox(height: ui.space.xxs),
                _DetailsMetricLine(
                  label: costLine.label,
                  value: costLine.value,
                ),
              ],
            ],
            if (tooltip!.maxDurationSeconds != null) ...[
              SizedBox(height: ui.space.xxs),
              _DetailsMetricLine(
                label: context.l10n.uiMaxDuration,
                value: context.gameL10n.durationSeconds(
                  seconds: (tooltip!.maxDurationSeconds! * 10).round() / 10,
                ),
              ),
            ],
            SizedBox(height: ui.space.xxs),
            UiSemanticRichText(
              semanticText: tooltip!.semanticDescription,
              normalStyleForTone: (tone) => ui.text.body.copyWith(
                color: switch (tone) {
                  UiSemanticTone.positive => ui.colors.success,
                  UiSemanticTone.negative => ui.colors.danger,
                  _ => ui.colors.textMuted,
                },
              ),
              highlightStyleForTone: (tone) => ui.text.body.copyWith(
                color: switch (tone) {
                  UiSemanticTone.positive => ui.colors.success,
                  UiSemanticTone.negative => ui.colors.danger,
                  _ => ui.colors.valueHighlight,
                },
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tooltip!.badges.isNotEmpty) ...[
              SizedBox(height: ui.space.xs),
              Wrap(
                spacing: ui.space.xs,
                runSpacing: ui.space.xs,
                children: [
                  for (final badge in tooltip!.badges)
                    _AbilityBadge(text: badge),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LockedAbilityDetailsPane extends StatelessWidget {
  const _LockedAbilityDetailsPane({
    required this.abilityId,
    required this.onFindInTown,
  });

  final AbilityKey abilityId;
  final VoidCallback onFindInTown;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GameIcon.ability(abilityId: abilityId, size: ui.sizes.iconSize.md),
            SizedBox(width: ui.space.sm),
            Expanded(
              child: Text(
                abilityDisplayName(abilityId, strings: context.gameL10n),
                style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
              ),
            ),
          ],
        ),
        SizedBox(height: ui.space.xs),
        Text(
          context.l10n.uiUnlockThisSkillInTownToViewFullDetails,
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
        SizedBox(height: ui.space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: context.l10n.uiFindInTown,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onPressed: onFindInTown,
          ),
        ),
      ],
    );
  }
}

class _DetailsMetricLine extends StatelessWidget {
  const _DetailsMetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    // Match gear compare rows: regular muted labels + emphasized values.
    final labelStyle = ui.text.body.copyWith(color: ui.colors.textMuted);
    final valueStyle = ui.text.body.copyWith(
      color: ui.colors.valueHighlight,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        style: labelStyle,
        children: [
          TextSpan(text: label, style: labelStyle),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
    );
  }
}

class _AbilityBadge extends StatelessWidget {
  const _AbilityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui.space.xs,
        vertical: ui.space.xxs,
      ),
      decoration: BoxDecoration(
        color: UiBrandPalette.steelBlueInsetBottom,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: ui.text.body.copyWith(
          color: ui.colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
