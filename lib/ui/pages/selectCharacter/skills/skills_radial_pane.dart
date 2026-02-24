import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/abilities/ability_def.dart';
import '../../../controls/action_button.dart';
import '../../../controls/ability_slot_visual_spec.dart';
import '../../../controls/controls_tuning.dart';
import '../../../controls/layout/controls_radial_layout.dart';
import '../../../theme/ui_tokens.dart';

class SkillsRadialPane extends StatelessWidget {
  const SkillsRadialPane({
    super.key,
    required this.selectedSlot,
    required this.onSelectSlot,
  });

  final AbilitySlot selectedSlot;
  final ValueChanged<AbilitySlot> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: _selectionActionSlotGeometry.width,
          height: _selectionActionSlotGeometry.height,
          child: Stack(
            children: [
              for (final slot in abilityRadialLayoutSpec.selectionOrder)
                Positioned(
                  left:
                      _selectionActionSlotGeometry.placements[slot]!.buttonLeft,
                  top: _selectionActionSlotGeometry.placements[slot]!.buttonTop,
                  child: _ActionSlotButton(
                    slot: slot,
                    selected: slot == selectedSlot,
                    onSelectSlot: onSelectSlot,
                    buttonSize: _selectionActionSlotGeometry
                        .placements[slot]!
                        .buttonSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSlotButton extends StatelessWidget {
  const _ActionSlotButton({
    required this.slot,
    required this.selected,
    required this.onSelectSlot,
    required this.buttonSize,
  });

  final AbilitySlot slot;
  final bool selected;
  final ValueChanged<AbilitySlot> onSelectSlot;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final slotVisual = abilityRadialLayoutSpec.slotSpec(slot);
    // Slightly oversize the ring so selection emphasis stays outside the icon.
    final borderWidth = buttonSize * 1.08;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ui.colors.accentStrong : Colors.transparent,
          width: borderWidth,
        ),
      ),
      child: Center(
        child: ActionButton(
          label: slotVisual.label,
          icon: slotVisual.icon,
          onPressed: () => onSelectSlot(slot),
          tuning: _actionButtonTuningForSelectionSlot(
            tuning: _selectionControlsTuning,
            slot: slot,
          ),
          cooldownRing: _selectionControlsTuning.style.cooldownRing,
          size: buttonSize,
        ),
      ),
    );
  }
}

@immutable
class _ActionSlotPlacement {
  const _ActionSlotPlacement({
    required this.buttonLeft,
    required this.buttonTop,
    required this.buttonSize,
  });

  final double buttonLeft;
  final double buttonTop;
  final double buttonSize;
}

@immutable
class _ActionSlotGeometry {
  const _ActionSlotGeometry({
    required this.width,
    required this.height,
    required this.placements,
  });

  final double width;
  final double height;
  final Map<AbilitySlot, _ActionSlotPlacement> placements;
}

/// Uses a fixed profile so selection-wheel geometry is stable across devices.
const ControlsTuning _selectionControlsTuning = ControlsTuning.fixed;
final ControlsRadialLayout _selectionControlsRadialLayout =
    ControlsRadialLayoutSolver.solve(
      layout: _selectionControlsTuning.layout,
      action: _selectionControlsTuning.style.actionButton,
      directional: _selectionControlsTuning.style.directionalActionButton,
    );
final _ActionSlotGeometry _selectionActionSlotGeometry =
    _buildActionSlotsGeometry(layout: _selectionControlsRadialLayout);

/// Converts radial anchor coordinates into normalized top-left placements.
///
/// The radial spec stores offsets from right/bottom edges. This helper mirrors
/// them into a local `Stack` coordinate space and shifts everything so the
/// smallest x/y starts at zero.
_ActionSlotGeometry _buildActionSlotsGeometry({
  required ControlsRadialLayout layout,
}) {
  final rawSizes = <AbilitySlot, double>{
    for (final slot in abilityRadialLayoutSpec.selectionOrder)
      slot: abilityRadialLayoutSpec.sizeFor(layout: layout, slot: slot),
  };
  var baseWidth = 0.0;
  var baseHeight = 0.0;
  for (final slot in abilityRadialLayoutSpec.selectionOrder) {
    final size = rawSizes[slot]!;
    final anchor = abilityRadialLayoutSpec.anchorFor(
      layout: layout,
      slot: slot,
    );
    baseWidth = math.max(baseWidth, anchor.right + size);
    baseHeight = math.max(baseHeight, anchor.bottom + size);
  }

  final rawPlacements = <AbilitySlot, _ActionSlotPlacement>{};
  for (final slot in abilityRadialLayoutSpec.selectionOrder) {
    final size = rawSizes[slot]!;
    final anchor = abilityRadialLayoutSpec.anchorFor(
      layout: layout,
      slot: slot,
    );
    final buttonLeft = baseWidth - anchor.right - size;
    final buttonTop = baseHeight - anchor.bottom - size;
    rawPlacements[slot] = _ActionSlotPlacement(
      buttonLeft: buttonLeft,
      buttonTop: buttonTop,
      buttonSize: size,
    );
  }

  // Compute bounds for the mirrored coordinates.
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final placement in rawPlacements.values) {
    minX = math.min(minX, placement.buttonLeft);
    minY = math.min(minY, placement.buttonTop);
    maxX = math.max(maxX, placement.buttonLeft + placement.buttonSize);
    maxY = math.max(maxY, placement.buttonTop + placement.buttonSize);
  }
  final shiftX = minX < 0 ? -minX : 0.0;
  final shiftY = minY < 0 ? -minY : 0.0;

  // Shift placements so parent `Stack` starts at (0, 0).
  final normalized = <AbilitySlot, _ActionSlotPlacement>{};
  for (final slot in abilityRadialLayoutSpec.selectionOrder) {
    final placement = rawPlacements[slot]!;
    normalized[slot] = _ActionSlotPlacement(
      buttonLeft: placement.buttonLeft + shiftX,
      buttonTop: placement.buttonTop + shiftY,
      buttonSize: placement.buttonSize,
    );
  }
  return _ActionSlotGeometry(
    width: maxX + shiftX,
    height: maxY + shiftY,
    placements: normalized,
  );
}

/// Resolves action button visuals for the selection wheel.
///
/// Directional slots reuse directional sizing metrics but are rendered with the
/// same high-contrast palette as regular selection buttons.
ActionButtonTuning _actionButtonTuningForSelectionSlot({
  required ControlsTuning tuning,
  required AbilitySlot slot,
}) {
  final family = abilityRadialLayoutSpec.slotSpec(slot).family;
  if (family == AbilityRadialSlotFamily.directional) {
    final directional = tuning.style.directionalActionButton;
    return _highContrastSelectionActionButtonTuning(
      ActionButtonTuning(
        size: directional.size,
        backgroundColor: directional.backgroundColor,
        foregroundColor: directional.foregroundColor,
        labelFontSize: directional.labelFontSize,
        labelGap: directional.labelGap,
      ),
    );
  }
  return _highContrastSelectionActionButtonTuning(tuning.style.actionButton);
}

/// Forces high-contrast icon buttons for menu readability.
ActionButtonTuning _highContrastSelectionActionButtonTuning(
  ActionButtonTuning base,
) {
  return ActionButtonTuning(
    size: base.size,
    backgroundColor: const Color(0xFFFFFFFF),
    foregroundColor: const Color(0xFF000000),
    labelFontSize: base.labelFontSize,
    labelGap: base.labelGap,
  );
}
