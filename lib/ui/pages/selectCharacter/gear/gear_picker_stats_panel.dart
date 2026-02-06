import 'package:flutter/material.dart';

import '../../../../core/meta/gear_slot.dart';
import '../../../text/gear_text.dart';
import '../../../theme/ui_tokens.dart';
import 'gear_picker_parts.dart';
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
    final cardPadding = ui.space.xs;
    final iconFrameSize = 38.0;
    final blockSpacing = ui.space.xs;

    return Container(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.4)),
        boxShadow: ui.shadows.card,
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (id == null)
            Expanded(
              child: Center(
                child: Text(
                  'Select an item to preview stats.',
                  style: ui.text.caption.copyWith(color: ui.colors.textMuted),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconFrameSize,
                        height: iconFrameSize,
                        decoration: BoxDecoration(
                          color: ui.colors.surface.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(ui.radii.sm),
                          border: Border.all(
                            color: ui.colors.outline.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: GearIcon(slot: slot, id: id!),
                      ),
                      SizedBox(width: ui.space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gearDisplayNameForSlot(slot, id!),
                              style: ui.text.caption.copyWith(
                                color: ui.colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '"${gearDescriptionForSlot(slot, id!)}"',
                              style: ui.text.caption.copyWith(
                                color: ui.colors.textMuted,
                                fontSize: 9,
                                height: 1.0,
                              ),
                              maxLines: 2,
                              softWrap: true,
                              overflow: TextOverflow.clip,
                            ),
                          ],
                        ),
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
                            title: 'Stats',
                            lines: lines,
                            emptyText: 'No non-zero stat bonuses.',
                          ),
                        ),
                        if (equippedForCompare != null) ...[
                          SizedBox(height: blockSpacing),
                          Expanded(
                            child: _StatSection(
                              title: 'Compared to equipped gear:',
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
  const _StatSection({
    required this.title,
    required this.lines,
    required this.emptyText,
  });

  final String title;
  final List<GearStatLine> lines;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final sectionPadding = const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 4,
    );
    final headingStyle = ui.text.caption.copyWith(
      color: ui.colors.textMuted,
      fontWeight: FontWeight.w700,
      fontSize: 10,
      height: 1.0,
    );
    final emptyStyle = ui.text.caption.copyWith(
      color: ui.colors.textMuted,
      fontSize: 10,
      height: 1.0,
    );
    const interItemGap = 2.0;
    const estimatedRowHeight = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableForRows =
            constraints.maxHeight - sectionPadding.vertical - 10 - interItemGap;
        // Clamp visible lines to the currently available section height to
        // avoid overflows in tighter landscape layouts.
        final maxRows = availableForRows.isFinite
            ? (availableForRows / estimatedRowHeight).floor()
            : lines.length;
        final safeMaxRows = maxRows < 1 ? 1 : maxRows;
        final visibleLines = lines.take(safeMaxRows).toList(growable: false);
        final hiddenLineCount = lines.length - visibleLines.length;

        return Container(
          width: double.infinity,
          padding: sectionPadding,
          decoration: BoxDecoration(
            color: ui.colors.surface.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(
              color: ui.colors.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: headingStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: interItemGap),
              if (lines.isEmpty)
                Text(
                  emptyText,
                  style: emptyStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else ...[
                for (final line in visibleLines) _StatLineText(line: line),
                if (hiddenLineCount > 0)
                  Text(
                    '+$hiddenLineCount more',
                    style: emptyStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ],
          ),
        );
      },
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
    final valueColor = switch (line.tone) {
      GearStatLineTone.neutral => ui.colors.textPrimary,
      GearStatLineTone.positive => ui.colors.success,
      GearStatLineTone.negative => ui.colors.danger,
    };
    final labelStyle = ui.text.caption.copyWith(
      color: ui.colors.textMuted,
      fontSize: 10,
      height: 1.0,
    );
    final valueStyle = ui.text.caption.copyWith(
      color: valueColor,
      fontWeight: FontWeight.w600,
      fontSize: 10,
      height: 1.0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            line.value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
