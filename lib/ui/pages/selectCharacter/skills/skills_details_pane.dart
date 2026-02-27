import 'package:flutter/material.dart';

import '../../../text/ability_tooltip_builder.dart';
import '../../../theme/ui_tokens.dart';

class SkillsDetailsPane extends StatelessWidget {
  const SkillsDetailsPane({super.key, required this.tooltip});

  final AbilityTooltip? tooltip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: _AbilityDetailsPane(tooltip: tooltip));
  }
}

class _AbilityDetailsPane extends StatelessWidget {
  const _AbilityDetailsPane({required this.tooltip});

  final AbilityTooltip? tooltip;

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
          if (tooltip == null) ...[
            Text(
              'No ability available for this slot.',
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
                label: 'Cooldown: ',
                value:
                    '${_formatCooldownSeconds(tooltip!.cooldownSeconds!)} seconds',
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
                label: 'Max duration: ',
                value:
                    '${_formatCooldownSeconds(tooltip!.maxDurationSeconds!)} seconds',
              ),
            ],
            SizedBox(height: ui.space.xxs),
            Text.rich(
              TextSpan(
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
                children: _buildDescriptionSpans(
                  description: tooltip!.description,
                  dynamicValues: tooltip!.dynamicDescriptionValues,
                  normalStyle: ui.text.body.copyWith(
                    color: ui.colors.textMuted,
                  ),
                  dynamicStyle: ui.text.body.copyWith(
                    color: ui.colors.valueHighlight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

/// Splits [description] into styled [TextSpan]s, highlighting [dynamicValues].
///
/// Values are matched longest-first to prevent partial overlaps when a shorter
/// token is a substring of a longer one (e.g. "5" inside "50%").
List<TextSpan> _buildDescriptionSpans({
  required String description,
  required List<String> dynamicValues,
  required TextStyle normalStyle,
  required TextStyle dynamicStyle,
}) {
  final values =
      dynamicValues.toSet().where((value) => value.isNotEmpty).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (values.isEmpty) {
    return <TextSpan>[TextSpan(text: description, style: normalStyle)];
  }

  final pattern = values.map(RegExp.escape).join('|');
  final regex = RegExp(pattern);
  final spans = <TextSpan>[];
  var index = 0;
  for (final match in regex.allMatches(description)) {
    if (match.start > index) {
      spans.add(
        TextSpan(
          text: description.substring(index, match.start),
          style: normalStyle,
        ),
      );
    }
    spans.add(TextSpan(text: match.group(0), style: dynamicStyle));
    index = match.end;
  }

  if (index < description.length) {
    spans.add(TextSpan(text: description.substring(index), style: normalStyle));
  }
  return spans;
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

String _formatCooldownSeconds(double seconds) {
  return seconds.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
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
