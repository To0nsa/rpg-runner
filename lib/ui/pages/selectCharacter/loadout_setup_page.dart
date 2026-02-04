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
import '../../components/app_tile_button.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'gear_picker_dialog.dart';

class LoadoutSetupPage extends StatelessWidget {
  const LoadoutSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoadoutSetupBody();
  }
}

class _LoadoutSetupBody extends StatefulWidget {
  const _LoadoutSetupBody();

  @override
  State<_LoadoutSetupBody> createState() => _LoadoutSetupBodyState();
}

class _LoadoutSetupBodyState extends State<_LoadoutSetupBody> {
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
        centerAppBarTitle: true,
        child: MenuLayout(
          scrollable: false,
          child: SizedBox.expand(
            child: TabBarView(
              children: [
                for (final def in defs)
                  _CharacterGearPanel(characterId: def.id),
              ],
            ),
          ),
        ),
      ),
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
      padding: EdgeInsets.symmetric(
        horizontal: ui.space.md,
        vertical: ui.space.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Equipped Gear', style: ui.text.headline),
          SizedBox(height: ui.space.xxs),
          Wrap(
            spacing: ui.space.md,
            runSpacing: ui.space.md,
            children: [
              AppTileButton(
                tooltip: 'Sword',
                onPressed: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.mainWeapon,
                ),
                child: UiIconTile(
                  coords: uiIconCoordsForWeapon(gear.mainWeaponId)!,
                ),
              ),
              AppTileButton(
                tooltip: 'Shield',
                onPressed: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.offhandWeapon,
                ),
                child: UiIconTile(
                  coords: uiIconCoordsForWeapon(gear.offhandWeaponId)!,
                ),
              ),
              AppTileButton(
                tooltip: 'Throw',
                onPressed: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.throwingWeapon,
                ),
                child: _throwingIconOrEmpty(gear.throwingWeaponId),
              ),
              AppTileButton(
                tooltip: 'Spellbook',
                onPressed: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.spellBook,
                ),
                child: UiIconTile(
                  coords: uiIconCoordsForSpellBook(gear.spellBookId)!,
                ),
              ),
              AppTileButton(
                tooltip: 'Accessory',
                onPressed: () => showGearPickerDialog(
                  context,
                  meta: meta,
                  service: service,
                  characterId: characterId,
                  slot: GearSlot.accessory,
                ),
                child: UiIconTile(
                  coords: uiIconCoordsForAccessory(gear.accessoryId)!,
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
