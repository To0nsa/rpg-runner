import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/meta/gear_slot.dart';
import '../../../core/meta/meta_service.dart';
import '../../../core/players/player_character_definition.dart';
import '../../components/gear_icon.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'gear/gear_picker_dialog.dart';

class GearsTab extends StatelessWidget {
  const GearsTab({super.key, required this.characterId});

  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final meta = appState.meta;
    final gear = meta.equippedFor(characterId);
    const service = MetaService();

    return Padding(
      padding: EdgeInsets.only(left: ui.space.xxs, top: ui.space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Equipped Gear', style: ui.text.headline),
          SizedBox(height: ui.space.xxs),
          Wrap(
            spacing: ui.space.xs,
            runSpacing: ui.space.xs,
            children: [
              _GearSlotButton(
                label: 'Sword',
                child: GearIcon(
                  slot: GearSlot.mainWeapon,
                  id: gear.mainWeaponId,
                ),
                onTap: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.mainWeapon,
                ),
              ),
              _GearSlotButton(
                label: 'Shield',
                child: GearIcon(
                  slot: GearSlot.offhandWeapon,
                  id: gear.offhandWeaponId,
                ),
                onTap: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.offhandWeapon,
                ),
              ),
              _GearSlotButton(
                label: 'Throw',
                child: GearIcon(
                  slot: GearSlot.throwingWeapon,
                  id: gear.throwingWeaponId,
                ),
                onTap: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.throwingWeapon,
                ),
              ),
              _GearSlotButton(
                label: 'Book',
                child: GearIcon(slot: GearSlot.spellBook, id: gear.spellBookId),
                onTap: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.spellBook,
                ),
              ),
              _GearSlotButton(
                label: 'Trinket',
                child: GearIcon(slot: GearSlot.accessory, id: gear.accessoryId),
                onTap: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.accessory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GearSlotButton extends StatelessWidget {
  const _GearSlotButton({
    required this.label,
    required this.child,
    required this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ui.radii.sm),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ui.colors.cardBackground,
                borderRadius: BorderRadius.circular(ui.radii.sm),
                border: Border.all(color: ui.colors.outline),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
        SizedBox(height: ui.space.xxs),
        Text(label, style: ui.text.caption),
      ],
    );
  }
}
