import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/abilities/ability_def.dart';
import '../../../controls/action_button.dart';
import '../../../controls/ability_slot_visual_spec.dart';
import '../../../controls/controls_tuning.dart';
import '../../../controls/layout/controls_radial_layout.dart';
import '../../../icons/ability_skill_icon.dart';
import '../../../theme/ui_action_button_theme.dart';
import '../../../theme/ui_skill_icon_theme.dart';

class SkillsRadialPane extends StatelessWidget {
  const SkillsRadialPane({
    super.key,
    required this.selectedSlot,
    required this.equippedAbilityIdsBySlot,
    required this.onSelectSlot,
  });

  final AbilitySlot selectedSlot;
  final Map<AbilitySlot, AbilityKey> equippedAbilityIdsBySlot;
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
                    abilityId: equippedAbilityIdsBySlot[slot],
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

class _ActionSlotButton extends StatefulWidget {
  const _ActionSlotButton({
    required this.slot,
    required this.abilityId,
    required this.selected,
    required this.onSelectSlot,
    required this.buttonSize,
  });

  final AbilitySlot slot;
  final AbilityKey? abilityId;
  final bool selected;
  final ValueChanged<AbilitySlot> onSelectSlot;
  final double buttonSize;

  @override
  State<_ActionSlotButton> createState() => _ActionSlotButtonState();
}

class _ActionSlotButtonState extends State<_ActionSlotButton> {
  final LayerLink _buttonLayerLink = LayerLink();
  OverlayEntry? _selectionRingOverlayEntry;
  bool _overlaySyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleOverlaySync();
  }

  @override
  void didUpdateWidget(covariant _ActionSlotButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selected) {
      _removeSelectionRingOverlay();
      return;
    }
    if (!oldWidget.selected || oldWidget.buttonSize != widget.buttonSize) {
      _scheduleOverlaySync();
      return;
    }
    _selectionRingOverlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _removeSelectionRingOverlay();
    super.dispose();
  }

  void _scheduleOverlaySync() {
    if (_overlaySyncScheduled) return;
    _overlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlaySyncScheduled = false;
      if (!mounted) return;
      _syncSelectionRingOverlay();
    });
  }

  void _syncSelectionRingOverlay() {
    if (!widget.selected) {
      _removeSelectionRingOverlay();
      return;
    }
    if (_selectionRingOverlayEntry != null) {
      _selectionRingOverlayEntry!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    // The ring is painted in the root overlay so it can extend into system
    // safe insets while the tap target remains safely inside page content.
    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: CompositedTransformFollower(
          link: _buttonLayerLink,
          showWhenUnlinked: false,
          offset: Offset(-_ringOffset, -_ringOffset),
          child: SizedBox(
            width: _outerRingSize,
            height: _outerRingSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: _ring.gradientColors,
                  stops: _ring.gradientStops,
                  transform: const GradientRotation(-math.pi / 2),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _ring.glowColor.withValues(alpha: _ring.glowAlpha),
                    blurRadius: _ring.glowBlurRadius,
                    spreadRadius: _ring.glowSpreadRadius,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _selectionRingOverlayEntry = entry;
    overlay.insert(entry);
  }

  void _removeSelectionRingOverlay() {
    final entry = _selectionRingOverlayEntry;
    if (entry == null) return;
    entry.remove();
    _selectionRingOverlayEntry = null;
  }

  UiActionButtonSelectionRing get _ring => context.actionButtons.selectionRing;

  double get _outerRingSize => widget.buttonSize * _ring.outerScale;

  double get _ringOffset => (_outerRingSize - widget.buttonSize) / 2;

  @override
  Widget build(BuildContext context) {
    final actionButtons = context.actionButtons;
    final iconSize = context.skillIcons.selectionRadialIconSize;
    final slotVisual = abilityRadialLayoutSpec.slotSpec(widget.slot);
    final buttonTuning = _actionButtonTuningForSelectionSlot(
      slot: widget.slot,
      actionTuning: actionButtons.resolveAction(
        base: _selectionControlsTuning.style.actionButton,
        surface: UiActionButtonSurface.selection,
      ),
      directionalTuning: actionButtons.resolveDirectional(
        base: _selectionControlsTuning.style.directionalActionButton,
        surface: UiActionButtonSurface.selection,
      ),
    );
    final button = ActionButton(
      label: slotVisual.label.toUpperCase(),
      icon: slotVisual.icon,
      iconWidget: AbilitySkillIcon(abilityId: widget.abilityId, size: iconSize),
      onPressed: () => widget.onSelectSlot(widget.slot),
      tuning: buttonTuning,
      cooldownRing: _selectionControlsTuning.style.cooldownRing,
      size: widget.buttonSize,
    );

    return CompositedTransformTarget(
      link: _buttonLayerLink,
      child: SizedBox(
        width: widget.buttonSize,
        height: widget.buttonSize,
        child: button,
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
  required AbilitySlot slot,
  required ActionButtonTuning actionTuning,
  required DirectionalActionButtonTuning directionalTuning,
}) {
  final family = abilityRadialLayoutSpec.slotSpec(slot).family;
  if (family == AbilityRadialSlotFamily.directional) {
    return ActionButtonTuning(
      size: directionalTuning.size,
      backgroundColor: directionalTuning.backgroundColor,
      foregroundColor: directionalTuning.foregroundColor,
      labelFontSize: directionalTuning.labelFontSize,
      labelGap: directionalTuning.labelGap,
    );
  }
  return actionTuning;
}
