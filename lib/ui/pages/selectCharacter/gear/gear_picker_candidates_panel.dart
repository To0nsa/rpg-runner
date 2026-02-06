import 'package:flutter/material.dart';

import '../../../../core/meta/gear_slot.dart';
import '../../../../core/meta/meta_service.dart';
import '../../../components/gear_icon.dart';
import '../../../theme/ui_tokens.dart';
import 'gear_picker_parts.dart';

/// Right-side candidate panel.
///
/// Renders all slot candidates (unlocked + locked), while keeping the grid
/// non-scrollable and dense for landscape-only presentation.
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
        final gridSpec = candidateGridSpecForAvailableSpace(
          itemCount: candidates.length,
          availableWidth: constraints.maxWidth,
          availableHeight: constraints.maxHeight,
          spacing: spacing,
        );

        return GridView.builder(
          itemCount: candidates.length,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSpec.crossAxisCount,
            mainAxisSpacing: gridSpec.spacing,
            crossAxisSpacing: gridSpec.spacing,
            mainAxisExtent: gridSpec.mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return _GearCandidateTile(
              slot: slot,
              id: candidate.id,
              isLocked: !candidate.isUnlocked,
              isEquipped: candidate.id == equippedId,
              selected: candidate.id == selectedId,
              // Locked candidates remain visible but are fully untappable.
              onTap: candidate.isUnlocked
                  ? () => onSelected(candidate.id)
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Fixed-size candidate tile used in the right panel grid.
class _GearCandidateTile extends StatelessWidget {
  const _GearCandidateTile({
    required this.slot,
    required this.id,
    required this.isLocked,
    required this.isEquipped,
    required this.selected,
    required this.onTap,
  });

  final GearSlot slot;
  final Object id;
  final bool isLocked;
  final bool isEquipped;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    const tileSize = 64.0;
    const iconSize = 48.0;
    const lockedFillColor = Color(0xFF171717);
    const selectedFillColor = Color(0xFF101010);
    const defaultFillColor = Color(0xFF131313);
    final borderColor = isLocked
        ? ui.colors.outline.withValues(alpha: 0.35)
        : selected
        ? ui.colors.accentStrong
        : (isEquipped ? ui.colors.success : ui.colors.outline);

    final fillColor = isLocked
        ? lockedFillColor
        : selected
        ? selectedFillColor
        : defaultFillColor;
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
                    child: Opacity(
                      opacity: isLocked ? 0.45 : 1,
                      child: GearIcon(slot: slot, id: id, size: iconSize),
                    ),
                  ),
                  if (isLocked)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Icon(
                        Icons.lock,
                        size: 10,
                        color: ui.colors.textMuted,
                      ),
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
