import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/meta/meta_service.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/players/player_character_registry.dart';
import '../../components/ability_placeholder_icon.dart';
import '../../components/gear_icon.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../text/ability_text.dart';
import '../../theme/ui_tokens.dart';
import 'ability/ability_picker_dialog.dart';
import 'ability/ability_picker_presenter.dart';
import 'gear/gear_picker_dialog.dart';

class LoadoutSetupPage extends StatefulWidget {
  const LoadoutSetupPage({super.key});

  @override
  State<LoadoutSetupPage> createState() => _LoadoutSetupPageState();
}

class _LoadoutSetupPageState extends State<LoadoutSetupPage> {
  bool _seeded = false;
  late int _initialTabIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final selection = context.read<AppState>().selection;
    final defs = PlayerCharacterRegistry.all;
    _initialTabIndex = defs.indexWhere(
      (d) => d.id == selection.selectedCharacterId,
    );
    if (_initialTabIndex < 0) _initialTabIndex = 0;
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final defs = PlayerCharacterRegistry.all;

    return DefaultTabController(
      length: defs.length,
      initialIndex: _initialTabIndex,
      child: MenuScaffold(
        appBarTitle: TabBar(
          isScrollable: true,
          labelColor: ui.colors.textPrimary,
          unselectedLabelColor: ui.colors.textMuted,
          labelStyle: ui.text.label,
          indicatorColor: ui.colors.accent,
          onTap: (index) {
            final def = defs[index];
            appState.setCharacter(def.id);
          },
          tabs: [for (final def in defs) Tab(text: def.displayName)],
        ),
        child: const MenuLayout(scrollable: false, child: _LoadoutSetupBody()),
      ),
    );
  }
}

class _LoadoutSetupBody extends StatelessWidget {
  const _LoadoutSetupBody();

  @override
  Widget build(BuildContext context) {
    final defs = PlayerCharacterRegistry.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TabBarView(
            // Keep character selection explicit: tabs change via click/tap only.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final def in defs) _CharacterGearPanel(characterId: def.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _CharacterGearPanel extends StatelessWidget {
  const _CharacterGearPanel({required this.characterId});

  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final meta = appState.meta;
    final loadout = appState.selection.equippedLoadout;
    final gear = meta.equippedFor(characterId);
    const service = MetaService();

    return Padding(
      padding: EdgeInsets.all(ui.space.xxs),
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
          SizedBox(height: ui.space.md),
          Text('Action Slots', style: ui.text.headline),
          SizedBox(height: ui.space.xs),
          _ActionSlotGrid(characterId: characterId, loadout: loadout),
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

class _ActionSlotGrid extends StatelessWidget {
  const _ActionSlotGrid({required this.characterId, required this.loadout});

  final PlayerCharacterId characterId;
  final EquippedLoadoutDef loadout;

  static const List<_ActionSlotSpec> _topRow = [
    _ActionSlotSpec(
      slot: AbilitySlot.mobility,
      hudLabel: 'Dash',
      isEditable: true,
    ),
    _ActionSlotSpec(
      slot: AbilitySlot.primary,
      hudLabel: 'Prim',
      isEditable: true,
    ),
    _ActionSlotSpec(
      slot: AbilitySlot.projectile,
      hudLabel: 'Proj',
      isEditable: true,
    ),
  ];

  static const List<_ActionSlotSpec> _bottomRow = [
    _ActionSlotSpec(
      slot: AbilitySlot.jump,
      hudLabel: 'Jump',
      isEditable: true,
    ),
    _ActionSlotSpec(
      slot: AbilitySlot.secondary,
      hudLabel: 'Shield',
      isEditable: true,
    ),
    _ActionSlotSpec(
      slot: AbilitySlot.spell,
      hudLabel: 'Spell',
      isEditable: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      children: [
        _ActionSlotRow(
          specs: _topRow,
          characterId: characterId,
          loadout: loadout,
        ),
        SizedBox(height: ui.space.xs),
        _ActionSlotRow(
          specs: _bottomRow,
          characterId: characterId,
          loadout: loadout,
        ),
      ],
    );
  }
}

class _ActionSlotRow extends StatelessWidget {
  const _ActionSlotRow({
    required this.specs,
    required this.characterId,
    required this.loadout,
  });

  final List<_ActionSlotSpec> specs;
  final PlayerCharacterId characterId;
  final EquippedLoadoutDef loadout;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Row(
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          Expanded(
            child: _ActionSlotButton(
              spec: specs[i],
              characterId: characterId,
              loadout: loadout,
            ),
          ),
          if (i < specs.length - 1) SizedBox(width: ui.space.xs),
        ],
      ],
    );
  }
}

class _ActionSlotButton extends StatelessWidget {
  const _ActionSlotButton({
    required this.spec,
    required this.characterId,
    required this.loadout,
  });

  final _ActionSlotSpec spec;
  final PlayerCharacterId characterId;
  final EquippedLoadoutDef loadout;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final abilityId = abilityIdForSlot(loadout, spec.slot);
    final abilityName = spec.isEditable
        ? abilityDisplayName(abilityId)
        : '${abilityDisplayName(abilityId)} (fixed)';
    final isEditable = spec.isEditable;
    const size = 56.0;
    final borderColor = isEditable
        ? ui.colors.outline
        : ui.colors.outline.withValues(alpha: 0.4);
    final iconColor = isEditable
        ? ui.colors.textPrimary
        : ui.colors.textMuted.withValues(alpha: 0.8);
    final iconLabel = _abilityPlaceholderLabel(abilityName);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEditable
                ? () => showAbilityPickerDialog(
                    context,
                    characterId: characterId,
                    slot: spec.slot,
                  )
                : null,
            customBorder: const CircleBorder(),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xFF131313),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AbilityPlaceholderIcon(
                    label: iconLabel,
                    size: 20,
                    enabled: isEditable,
                  ),
                  SizedBox(height: ui.space.xxs),
                  Text(
                    spec.hudLabel,
                    style: ui.text.caption.copyWith(
                      color: iconColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: ui.space.xxs),
        Text(
          abilityName,
          style: ui.text.caption.copyWith(
            color: isEditable ? ui.colors.textPrimary : ui.colors.textMuted,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ActionSlotSpec {
  const _ActionSlotSpec({
    required this.slot,
    required this.hudLabel,
    required this.isEditable,
  });

  final AbilitySlot slot;
  final String hudLabel;
  final bool isEditable;
}

String _abilityPlaceholderLabel(String abilityName) {
  final cleaned = abilityName.replaceAll('(', '').replaceAll(')', '').trim();
  final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final buffer = StringBuffer();
  for (final word in words) {
    buffer.write(word[0].toUpperCase());
    if (buffer.length >= 2) break;
  }
  final value = buffer.toString();
  return value.isEmpty ? '?' : value;
}
