import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/ui/controls/ability_slot_visual_spec.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/layout/controls_radial_layout.dart';

void main() {
  test('radial layout spec exposes canonical labels, icons, and families', () {
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.primary).label,
      'Sword',
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.primary).icon,
      Icons.sports_martial_arts_rounded,
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.primary).family,
      AbilityRadialSlotFamily.directional,
    );

    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.secondary).label,
      'Shield',
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.secondary).icon,
      Icons.shield,
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.secondary).family,
      AbilityRadialSlotFamily.action,
    );

    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.projectile).label,
      'Projectile',
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.projectile).icon,
      Icons.auto_awesome,
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.projectile).family,
      AbilityRadialSlotFamily.directional,
    );

    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.mobility).label,
      'Mobility',
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.mobility).icon,
      Icons.flash_on,
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.mobility).family,
      AbilityRadialSlotFamily.action,
    );

    expect(abilityRadialLayoutSpec.slotSpec(AbilitySlot.jump).label, 'Jump');
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.jump).icon,
      Icons.arrow_upward,
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.jump).family,
      AbilityRadialSlotFamily.jump,
    );

    expect(abilityRadialLayoutSpec.slotSpec(AbilitySlot.spell).label, 'Spell');
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.spell).icon,
      Icons.star,
    );
    expect(
      abilityRadialLayoutSpec.slotSpec(AbilitySlot.spell).family,
      AbilityRadialSlotFamily.action,
    );
  });

  test('selection order is deterministic and complete', () {
    expect(abilityRadialLayoutSpec.selectionOrder, const <AbilitySlot>[
      AbilitySlot.jump,
      AbilitySlot.mobility,
      AbilitySlot.primary,
      AbilitySlot.secondary,
      AbilitySlot.projectile,
      AbilitySlot.spell,
    ]);
    expect(
      abilityRadialLayoutSpec.selectionOrder.toSet(),
      AbilitySlot.values.toSet(),
    );
  });

  test(
    'radial layout mapping resolves the expected anchor and size for each slot',
    () {
      const tuning = ControlsTuning.fixed;
      final layout = ControlsRadialLayoutSolver.solve(
        layout: tuning.layout,
        action: tuning.style.actionButton,
        directional: tuning.style.directionalActionButton,
      );

      final primaryAnchor = abilityRadialLayoutSpec.anchorFor(
        layout: layout,
        slot: AbilitySlot.primary,
      );
      expect(primaryAnchor.right, layout.melee.right);
      expect(primaryAnchor.bottom, layout.melee.bottom);
      expect(
        abilityRadialLayoutSpec.sizeFor(
          layout: layout,
          slot: AbilitySlot.primary,
        ),
        layout.directionalSize,
      );

      final jumpAnchor = abilityRadialLayoutSpec.anchorFor(
        layout: layout,
        slot: AbilitySlot.jump,
      );
      expect(jumpAnchor.right, layout.jump.right);
      expect(jumpAnchor.bottom, layout.jump.bottom);
      expect(
        abilityRadialLayoutSpec.sizeFor(layout: layout, slot: AbilitySlot.jump),
        layout.jumpSize,
      );
    },
  );
}
