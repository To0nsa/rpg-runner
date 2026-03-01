import 'package:flutter/material.dart';

import '../../../../core/meta/gear_slot.dart';
import '../../../text/gear_text.dart';
import '../../../text/semantic_text.dart';
import '../../../theme/ui_tokens.dart';
import 'gear_stats_presenter.dart';

/// Left-side stats panel for the currently selected gear.
///
/// Pure display widget: it consumes precomputed stat lines from
/// [gear_stats_presenter.dart] and does not mutate state.
class GearPickerStatsPanel extends StatelessWidget {
  const GearPickerStatsPanel({
    super.key,
    required this.slot,
    required this.id,
    this.equippedForCompare,
  });

  final GearSlot slot;
  final Object? id;
  final Object? equippedForCompare;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final lines = id == null ? const <GearStatLine>[] : gearStatsFor(slot, id!);
    final compareLines = (id == null || equippedForCompare == null)
        ? const <GearStatLine>[]
        : gearCompareStats(slot, equipped: equippedForCompare!, candidate: id!);
    final compareEmptyText = gearCompareEmptyText(
      selectedId: id,
      equippedForCompare: equippedForCompare,
    );
    final horizontalPadding = ui.space.xs;
    final verticalPadding = ui.space.xxs;
    final blockSpacing = ui.space.xs;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (id == null)
            Expanded(
              child: Center(
                child: Text(
                  'Select an item to preview stats.',
                  style: ui.text.body.copyWith(color: ui.colors.textMuted),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        gearDisplayNameForSlot(slot, id!),
                        style: ui.text.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '"${gearDescriptionForSlot(slot, id!)}"',
                        style: ui.text.body.copyWith(
                          color: ui.colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  SizedBox(height: blockSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatSection(
                            lines: lines,
                            emptyText: 'No non-zero stat bonuses.',
                          ),
                        ),
                        if (equippedForCompare != null) ...[
                          SizedBox(height: blockSpacing),
                          Expanded(
                            child: _StatSection(
                              lines: compareLines,
                              emptyText: compareEmptyText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small bordered section used for base stats and compare stats.
class _StatSection extends StatelessWidget {
  const _StatSection({required this.lines, required this.emptyText});

  final List<GearStatLine> lines;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final sectionFillColor = ui.colors.background;
    final sectionPadding = const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 4,
    );
    final emptyStyle = ui.text.body.copyWith(color: ui.colors.textMuted);
    const interItemGap = 2.0;
    return Container(
      width: double.infinity,
      padding: sectionPadding,
      decoration: BoxDecoration(
        color: sectionFillColor,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      child: lines.isEmpty
          ? Padding(
              padding: EdgeInsets.only(top: interItemGap),
              child: Text(
                emptyText,
                style: emptyStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.only(top: interItemGap),
              itemCount: lines.length,
              itemBuilder: (context, index) =>
                  _StatLineText(line: lines[index]),
              separatorBuilder: (context, index) =>
                  SizedBox(height: interItemGap),
            ),
    );
  }
}

/// Single stat row with contextual value color (neutral/positive/negative).
class _StatLineText extends StatelessWidget {
  const _StatLineText({required this.line});

  final GearStatLine line;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final isProcDetailLine = line.label.startsWith('On ');
    final valueColor = switch (line.tone) {
      GearStatLineTone.neutral => ui.colors.textPrimary,
      GearStatLineTone.positive => ui.colors.success,
      GearStatLineTone.negative => ui.colors.danger,
      GearStatLineTone.accent => ui.colors.valueHighlight,
    };
    final labelStyle = ui.text.body.copyWith(color: ui.colors.textMuted);
    final valueStyle = ui.text.body.copyWith(
      color: valueColor,
      fontWeight: FontWeight.w600,
    );
    final procNormalStyle = ui.text.body.copyWith(
      color: ui.colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final semanticValue =
        line.semanticValue ??
        (line.highlights.isEmpty
            ? null
            : UiSemanticText.single(line.value, highlights: line.highlights));

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              line.label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: isProcDetailLine ? 14 : 4,
            child: semanticValue == null
                ? Text(
                    line.value,
                    style: valueStyle,
                    textAlign: isProcDetailLine
                        ? TextAlign.left
                        : TextAlign.right,
                  )
                : UiSemanticRichText(
                    semanticText: semanticValue,
                    normalStyleForTone: (_) => procNormalStyle,
                    highlightStyleForTone: (tone) => ui.text.body.copyWith(
                      color: _colorForTone(ui, tone),
                      fontWeight: FontWeight.w600,
                    ),
                    mapHighlightTone: line.forcePositiveHighlightTones
                        ? (_) => UiSemanticTone.positive
                        : null,
                    textAlign: isProcDetailLine
                        ? TextAlign.left
                        : TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }
}

Color _colorForTone(UiTokens ui, GearStatLineTone tone) {
  return switch (tone) {
    GearStatLineTone.neutral => ui.colors.textPrimary,
    GearStatLineTone.positive => ui.colors.success,
    GearStatLineTone.negative => ui.colors.danger,
    GearStatLineTone.accent => ui.colors.valueHighlight,
  };
}
