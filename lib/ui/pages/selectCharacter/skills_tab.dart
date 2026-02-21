import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/players/player_character_definition.dart';
import '../../controls/action_button.dart';
import '../../controls/ability_slot_visual_spec.dart';
import '../../controls/controls_tuning.dart';
import '../../controls/layout/controls_radial_layout.dart';
import '../../theme/ui_tokens.dart';
import 'ability/ability_picker_dialog.dart';

class SkillsBar extends StatelessWidget {
  const SkillsBar({super.key, required this.characterId});

  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.only(left: ui.space.xxs, top: ui.space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _ActionSlotRadialPanel(characterId: characterId)),
        ],
      ),
    );
  }
}

class _ActionSlotRadialPanel extends StatelessWidget {
  const _ActionSlotRadialPanel({required this.characterId});

  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(
          width: _selectionActionSlotGeometry.width,
          height: _selectionActionSlotGeometry.height,
          child: Stack(
            children: [
              for (final slot in abilityRadialLayoutSpec.selectionOrder) ...[
                Positioned(
                  left:
                      _selectionActionSlotGeometry.placements[slot]!.buttonLeft,
                  top: _selectionActionSlotGeometry.placements[slot]!.buttonTop,
                  child: _ActionSlotButton(
                    slot: slot,
                    characterId: characterId,
                    buttonSize: _selectionActionSlotGeometry
                        .placements[slot]!
                        .buttonSize,
                  ),
                ),
              ],
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
    required this.characterId,
    required this.buttonSize,
  });

  final AbilitySlot slot;
  final PlayerCharacterId characterId;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final slotVisual = abilityRadialLayoutSpec.slotSpec(slot);
    return ActionButton(
      label: slotVisual.label,
      icon: slotVisual.icon,
      onPressed: () => showAbilityPickerDialog(
        context,
        characterId: characterId,
        slot: slot,
      ),
      tuning: _actionButtonTuningForSelectionSlot(
        tuning: _selectionControlsTuning,
        slot: slot,
      ),
      cooldownRing: _selectionControlsTuning.style.cooldownRing,
      size: buttonSize,
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

const ControlsTuning _selectionControlsTuning = ControlsTuning.fixed;
final ControlsRadialLayout _selectionControlsRadialLayout =
    ControlsRadialLayoutSolver.solve(
      layout: _selectionControlsTuning.layout,
      action: _selectionControlsTuning.style.actionButton,
      directional: _selectionControlsTuning.style.directionalActionButton,
    );
final _ActionSlotGeometry _selectionActionSlotGeometry =
    _buildActionSlotsGeometry(layout: _selectionControlsRadialLayout);

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
