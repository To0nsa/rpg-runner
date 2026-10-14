import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:runner_core/abilities/ability_def.dart';

import 'layout/controls_radial_layout.dart';

/// Visual family used to resolve slot button size/tuning.
enum AbilityRadialSlotFamily { action, directional, jump }

/// Anchor identifier in the radial HUD layout.
enum AbilityRadialAnchor { jump, dash, melee, secondary, projectile, spell }

/// Shared slot metadata consumed by both run HUD and loadout radial preview.
@immutable
class AbilityRadialSlotSpec {
  const AbilityRadialSlotSpec({
    required this.slot,
    required this.label,
    required this.icon,
    required this.anchor,
    required this.family,
  });

  final AbilitySlot slot;
  final String label;
  final IconData icon;
  final AbilityRadialAnchor anchor;
  final AbilityRadialSlotFamily family;
}

/// Single source of truth for ability radial slots.
@immutable
class AbilityRadialLayoutSpec {
  const AbilityRadialLayoutSpec({
    required this.slots,
    required this.selectionOrder,
  });

  final List<AbilityRadialSlotSpec> slots;

  /// Slot order used by the loadout radial preview.
  final List<AbilitySlot> selectionOrder;

  AbilityRadialSlotSpec slotSpec(AbilitySlot slot) {
    for (final spec in slots) {
      if (spec.slot == slot) return spec;
    }
    throw StateError('No AbilityRadialSlotSpec found for slot: $slot');
  }

  ControlsAnchor anchorFor({
    required ControlsRadialLayout layout,
    required AbilitySlot slot,
  }) {
    final spec = slotSpec(slot);
    switch (spec.anchor) {
      case AbilityRadialAnchor.jump:
        return layout.jump;
      case AbilityRadialAnchor.dash:
        return layout.dash;
      case AbilityRadialAnchor.melee:
        return layout.melee;
      case AbilityRadialAnchor.secondary:
        return layout.secondary;
      case AbilityRadialAnchor.projectile:
        return layout.projectile;
      case AbilityRadialAnchor.spell:
        return layout.spell;
    }
  }

  double sizeFor({
    required ControlsRadialLayout layout,
    required AbilitySlot slot,
    AbilityRadialSlotFamily? familyOverride,
  }) {
    final family = familyOverride ?? slotSpec(slot).family;
    return sizeForFamily(layout: layout, family: family);
  }

  double sizeForFamily({
    required ControlsRadialLayout layout,
    required AbilityRadialSlotFamily family,
  }) {
    switch (family) {
      case AbilityRadialSlotFamily.action:
        return layout.actionSize;
      case AbilityRadialSlotFamily.directional:
        return layout.directionalSize;
      case AbilityRadialSlotFamily.jump:
        return layout.jumpSize;
    }
  }
}

const AbilityRadialLayoutSpec abilityRadialLayoutSpec = AbilityRadialLayoutSpec(
  slots: <AbilityRadialSlotSpec>[
    AbilityRadialSlotSpec(
      slot: AbilitySlot.primary,
      label: 'Sword',
      icon: LucideIcons.sword400,
      anchor: AbilityRadialAnchor.melee,
      family: AbilityRadialSlotFamily.directional,
    ),
    AbilityRadialSlotSpec(
      slot: AbilitySlot.secondary,
      label: 'Shield',
      icon: LucideIcons.shield400,
      anchor: AbilityRadialAnchor.secondary,
      family: AbilityRadialSlotFamily.action,
    ),
    AbilityRadialSlotSpec(
      slot: AbilitySlot.projectile,
      label: 'Projectile',
      icon: LucideIcons.bowArrow400,
      anchor: AbilityRadialAnchor.projectile,
      family: AbilityRadialSlotFamily.directional,
    ),
    AbilityRadialSlotSpec(
      slot: AbilitySlot.mobility,
      label: 'Mobility',
      icon: LucideIcons.wind400,
      anchor: AbilityRadialAnchor.dash,
      family: AbilityRadialSlotFamily.action,
    ),
    AbilityRadialSlotSpec(
      slot: AbilitySlot.jump,
      label: 'Jump',
      icon: LucideIcons.arrowUpFromLine400,
      anchor: AbilityRadialAnchor.jump,
      family: AbilityRadialSlotFamily.jump,
    ),
    AbilityRadialSlotSpec(
      slot: AbilitySlot.spell,
      label: 'Spell',
      icon: LucideIcons.wandSparkles400,
      anchor: AbilityRadialAnchor.spell,
      family: AbilityRadialSlotFamily.action,
    ),
  ],
  selectionOrder: <AbilitySlot>[
    AbilitySlot.jump,
    AbilitySlot.mobility,
    AbilitySlot.primary,
    AbilitySlot.secondary,
    AbilitySlot.projectile,
    AbilitySlot.spell,
  ],
);
