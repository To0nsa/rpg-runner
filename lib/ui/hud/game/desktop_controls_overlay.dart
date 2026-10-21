import 'package:flutter/material.dart';
import 'package:runner_core/abilities/ability_def.dart';

import '../../../game/game_controller.dart';
import '../../controls/ability_slot_visual_spec.dart';
import '../../theme/ui_tokens.dart';

/// Snapshot-only desktop status. The panel absorbs clicks so reading a binding
/// cannot trigger an attack on the gameplay surface underneath it.
class DesktopControlsOverlay extends StatelessWidget {
  const DesktopControlsOverlay({
    super.key,
    required this.controller,
    required this.panelKey,
  });

  final GameController controller;
  final GlobalKey panelKey;

  @override
  Widget build(BuildContext context) {
    final hud = controller.snapshot.hud;
    final ui = context.ui;
    final slots =
        <
          ({
            AbilitySlot slot,
            String binding,
            bool valid,
            bool affordable,
            int? cooldown,
          })
        >[
          (
            slot: AbilitySlot.jump,
            binding: 'Space / W / Up',
            valid: hud.jumpSlotValid,
            affordable: hud.canAffordJump,
            cooldown: null,
          ),
          (
            slot: AbilitySlot.mobility,
            binding: 'Shift',
            valid: hud.mobilitySlotValid,
            affordable: hud.canAffordMobility,
            cooldown: CooldownGroup.mobility,
          ),
          (
            slot: AbilitySlot.primary,
            binding: 'LMB / J',
            valid: hud.meleeSlotValid,
            affordable: hud.canAffordMelee,
            cooldown: CooldownGroup.primary,
          ),
          if (hud.hasSecondarySlot)
            (
              slot: AbilitySlot.secondary,
              binding: 'Q',
              valid: hud.secondarySlotValid,
              affordable: hud.canAffordSecondary,
              cooldown: CooldownGroup.secondary,
            ),
          if (hud.hasProjectileSlot)
            (
              slot: AbilitySlot.projectile,
              binding: 'RMB / K',
              valid: hud.projectileSlotValid,
              affordable: hud.canAffordProjectile,
              cooldown: CooldownGroup.projectile,
            ),
          (
            slot: AbilitySlot.spell,
            binding: 'E / L',
            valid: hud.spellSlotValid,
            affordable: hud.canAffordSpell,
            cooldown: CooldownGroup.spell0,
          ),
        ];
    return SafeArea(
      minimum: EdgeInsets.all(ui.space.xs),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          child: Container(
            key: panelKey,
            padding: EdgeInsets.all(ui.space.xs),
            decoration: BoxDecoration(
              color: ui.colors.background.withValues(alpha: 0.9),
              border: Border.all(color: ui.colors.outline),
              borderRadius: BorderRadius.circular(ui.radii.sm),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: ui.space.sm,
                  runSpacing: ui.space.xs,
                  children: [
                    for (final item in slots)
                      Builder(
                        builder: (context) {
                          final recast =
                              item.slot == AbilitySlot.mobility &&
                              hud.mobilityRecastTicksLeft > 0;
                          final remaining = item.cooldown == null
                              ? 0
                              : hud.cooldownTicksLeft[item.cooldown!];
                          final status = !item.valid
                              ? 'Unavailable'
                              : !item.affordable
                              ? 'Low resource'
                              : recast
                              ? 'Follow-up'
                              : remaining > 0
                              ? '${(remaining / controller.tickHz).toStringAsFixed(1)}s'
                              : 'Ready';
                          final color =
                              !item.valid ||
                                  !item.affordable ||
                                  (remaining > 0 && !recast)
                              ? ui.colors.textMuted
                              : ui.colors.textPrimary;
                          final spec = abilityRadialLayoutSpec.slotSpec(
                            item.slot,
                          );
                          return Semantics(
                            label: '${spec.label}, ${item.binding}, $status',
                            excludeSemantics: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  abilityRadialLayoutSpec.iconFor(
                                    item.slot,
                                    abilityId: item.slot == AbilitySlot.spell
                                        ? hud.abilitySpellId
                                        : null,
                                  ),
                                  color: color,
                                  size: ui.sizes.iconSize.md,
                                ),
                                Text(
                                  item.binding,
                                  style: ui.text.label.copyWith(color: color),
                                ),
                                Text(
                                  status,
                                  style: ui.text.body.copyWith(color: color),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (hud.chargeEnabled && hud.chargeActive)
                  Padding(
                    padding: EdgeInsets.only(top: ui.space.xxs),
                    child: Text(
                      'Charge ${hud.chargeFullTicks > 0 ? (100 * hud.chargeTicks / hud.chargeFullTicks).clamp(0, 100).round() : 0}%',
                      style: ui.text.label,
                    ),
                  ),
                SizedBox(height: ui.space.xxs),
                Text(
                  'A / D or arrows: Move | Mouse: Aim | Esc / P: Pause | Enter: Resume',
                  textAlign: TextAlign.center,
                  style: ui.text.body.copyWith(color: ui.colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
