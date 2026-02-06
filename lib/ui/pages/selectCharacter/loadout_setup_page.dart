import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/meta/gear_slot.dart';
import '../../../core/meta/meta_service.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/players/player_character_registry.dart';
import '../../../core/projectiles/projectile_item_id.dart';
import '../../icons/throwing_weapon_asset.dart';
import '../../icons/ui_icon_coords.dart';
import '../../icons/ui_icon_tile.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';
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
    final gear = meta.equippedFor(characterId);
    const service = MetaService();

    return Padding(
      padding: EdgeInsets.all(ui.space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Equipped Gear', style: ui.text.headline),
          SizedBox(height: ui.space.md),
          Wrap(
            spacing: ui.space.md,
            runSpacing: ui.space.md,
            children: [
              _GearSlotButton(
                label: 'Sword',
                child: UiIconTile(
                  coords: uiIconCoordsForWeapon(gear.mainWeaponId)!,
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
                child: UiIconTile(
                  coords: uiIconCoordsForWeapon(gear.offhandWeaponId)!,
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
                child: _throwingIconOrEmpty(gear.throwingWeaponId),
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
                child: UiIconTile(
                  coords: uiIconCoordsForSpellBook(gear.spellBookId)!,
                ),
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
                child: UiIconTile(
                  coords: uiIconCoordsForAccessory(gear.accessoryId)!,
                ),
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

Widget _throwingIconOrEmpty(ProjectileItemId id) {
  final path = throwingWeaponAssetPath(id);
  if (path == null) return const SizedBox.shrink();
  return Image.asset(path, width: 32, height: 32);
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
              width: 32,
              height: 32,
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
        SizedBox(height: ui.space.xs),
        Text(label, style: ui.text.caption),
      ],
    );
  }
}
