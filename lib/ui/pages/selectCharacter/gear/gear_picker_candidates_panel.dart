import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/meta/gear_slot.dart';
import '../../../../core/meta/meta_service.dart';
import '../../../components/gear_icon.dart';
import '../../../theme/ui_tokens.dart';
import 'gear_picker_parts.dart';

/// Right-side candidate panel.
///
/// Renders unlocked slot candidates while keeping the grid non-scrollable and
/// dense for landscape-only presentation.
class GearPickerCandidatesPanel extends StatelessWidget {
  const GearPickerCandidatesPanel({
    super.key,
    required this.slot,
    required this.candidates,
    required this.equippedId,
    required this.selectedId,
    required this.onSelected,
  });

  final GearSlot slot;
  final List<GearSlotCandidate> candidates;
  final Object equippedId;
  final Object? selectedId;
  final ValueChanged<Object> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    if (candidates.isEmpty) {
      return Center(
        child: Text(
          'No options for this slot.',
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = ui.space.xs;
        const targetColumns = 5;
        const targetRows = 3;
        final widthPerTile =
            (constraints.maxWidth - (spacing * (targetColumns - 1))) /
            targetColumns;
        final heightPerTile =
            (constraints.maxHeight - (spacing * (targetRows - 1))) / targetRows;
        final tileSize = math
            .min(widthPerTile, heightPerTile)
            .clamp(44.0, 64.0)
            .toDouble();
        final targetCapacity = targetColumns * targetRows;
        final itemCount = math.max(candidates.length, targetCapacity);

        return GridView.builder(
          itemCount: itemCount,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: targetColumns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: tileSize,
          ),
          itemBuilder: (context, index) {
            if (index >= candidates.length) {
              return _EmptyGearCandidateTile(tileSize: tileSize);
            }
            final candidate = candidates[index];
            return _GearCandidateTile(
              slot: slot,
              id: candidate.id,
              tileSize: tileSize,
              isEquipped: candidate.id == equippedId,
              selected: candidate.id == selectedId,
              onTap: () => onSelected(candidate.id),
            );
          },
        );
      },
    );
  }
}

class _EmptyGearCandidateTile extends StatelessWidget {
  const _EmptyGearCandidateTile({required this.tileSize});

  final double tileSize;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Align(
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: tileSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ui.colors.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(
              color: ui.colors.outline.withValues(alpha: 0.22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed-size candidate tile used in the right panel grid.
class _GearCandidateTile extends StatelessWidget {
  const _GearCandidateTile({
    required this.slot,
    required this.id,
    required this.tileSize,
    required this.isEquipped,
    required this.selected,
    required this.onTap,
  });

  final GearSlot slot;
  final Object id;
  final double tileSize;
  final bool isEquipped;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final iconSize = (tileSize * 0.75).clamp(24.0, 48.0);
    final selectedFillColor = UiBrandPalette.steelBlueInsetBottom;
    final defaultFillColor = ui.colors.cardBackground;
    final borderColor = selected
        ? ui.colors.accentStrong
        : (isEquipped ? ui.colors.success : ui.colors.outline);
    final fillColor = selected ? selectedFillColor : defaultFillColor;
    final radius = ui.radii.sm;

    return Align(
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: tileSize,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: borderColor,
                  width: selected ? ui.sizes.borderWidth : 1,
                ),
                boxShadow: selected ? ui.shadows.card : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: GearIcon(slot: slot, id: id, size: iconSize),
                  ),
                  if (isEquipped || selected)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isEquipped) StateDot(color: ui.colors.success),
                          if (isEquipped && selected) const SizedBox(width: 2),
                          if (selected) StateDot(color: ui.colors.accentStrong),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
