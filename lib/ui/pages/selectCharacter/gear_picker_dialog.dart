import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/accessories/accessory_catalog.dart';
import '../../../core/accessories/accessory_def.dart';
import '../../../core/accessories/accessory_id.dart';
import '../../../core/meta/equipped_gear.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/meta/meta_service.dart';
import '../../../core/meta/meta_state.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/projectiles/projectile_item_catalog.dart';
import '../../../core/projectiles/projectile_item_def.dart';
import '../../../core/projectiles/projectile_item_id.dart';
import '../../../core/spells/spell_book_catalog.dart';
import '../../../core/spells/spell_book_def.dart';
import '../../../core/spells/spell_book_id.dart';
import '../../../core/weapons/weapon_catalog.dart';
import '../../../core/weapons/weapon_def.dart';
import '../../../core/weapons/weapon_id.dart';
import '../../../core/weapons/weapon_stats.dart';
import '../../icons/throwing_weapon_asset.dart';
import '../../icons/ui_icon_coords.dart';
import '../../icons/ui_icon_tile.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';

Future<void> showGearPickerDialog(
  BuildContext context, {
  required MetaState meta,
  required MetaService service,
  required PlayerCharacterId characterId,
  required GearSlot slot,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: context.ui.colors.scrim,
    builder: (dialogContext) {
      return _GearPickerDialog(
        meta: meta,
        service: service,
        characterId: characterId,
        slot: slot,
      );
    },
  );
}

class _GearPickerDialog extends StatefulWidget {
  const _GearPickerDialog({
    required this.meta,
    required this.service,
    required this.characterId,
    required this.slot,
  });

  final MetaState meta;
  final MetaService service;
  final PlayerCharacterId characterId;
  final GearSlot slot;

  @override
  State<_GearPickerDialog> createState() => _GearPickerDialogState();
}

class _GearPickerDialogState extends State<_GearPickerDialog> {
  Object? _selectedCandidate;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final equipped = widget.meta.equippedFor(widget.characterId);

    final equippedId = _equippedIdForSlot(widget.slot, equipped);
    final candidates = _candidatesForSlot(
      widget.slot,
      widget.service,
      widget.meta,
    );

    final selected = _selectedCandidate;
    final canSwap = selected != null && selected != equippedId;

    return Dialog(
      backgroundColor: ui.colors.surface,
      insetPadding: EdgeInsets.all(ui.space.lg),
      child: SizedBox(
        width: 920,
        height: 520,
        child: Padding(
          padding: EdgeInsets.all(ui.space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GearStatsCard(
                      title: 'Equipped',
                      slot: widget.slot,
                      id: equippedId,
                    ),
                    SizedBox(height: ui.space.sm),
                    Expanded(
                      child: _GearStatsCard(
                        title: 'Selected',
                        slot: widget.slot,
                        id: selected,
                        equippedForCompare: equippedId,
                      ),
                    ),
                    SizedBox(height: ui.space.sm),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        const Spacer(),
                        Tooltip(
                          message: canSwap ? 'Equip' : 'Select an item',
                          child: InkWell(
                            onTap: canSwap
                                ? () async {
                                    final candidate = _selectedCandidate;
                                    if (candidate == null) return;
                                    await appState.equipGear(
                                      characterId: widget.characterId,
                                      slot: widget.slot,
                                      itemId: candidate,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(ui.radii.sm),
                            child: Opacity(
                              opacity: canSwap ? 1.0 : 0.4,
                              child: Padding(
                                padding: EdgeInsets.all(ui.space.xs),
                                child: UiIconTile(coords: swapGearIconCoords),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: ui.space.md),
              Expanded(
                child: _GearCandidateGrid(
                  slot: widget.slot,
                  candidates: candidates,
                  equippedId: equippedId,
                  selectedId: selected,
                  onSelected: (value) =>
                      setState(() => _selectedCandidate = value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Object _equippedIdForSlot(GearSlot slot, EquippedGear equipped) {
  return switch (slot) {
    GearSlot.mainWeapon => equipped.mainWeaponId,
    GearSlot.offhandWeapon => equipped.offhandWeaponId,
    GearSlot.throwingWeapon => equipped.throwingWeaponId,
    GearSlot.spellBook => equipped.spellBookId,
    GearSlot.accessory => equipped.accessoryId,
  };
}

List<Object> _candidatesForSlot(
  GearSlot slot,
  MetaService service,
  MetaState meta,
) {
  return switch (slot) {
    GearSlot.mainWeapon => service.unlockedMainWeapons(meta),
    GearSlot.offhandWeapon => service.unlockedOffhands(meta),
    GearSlot.throwingWeapon => service.unlockedThrowingWeapons(meta),
    GearSlot.spellBook => service.unlockedSpellBooks(meta),
    GearSlot.accessory => service.unlockedAccessories(meta),
  };
}

class _GearCandidateGrid extends StatelessWidget {
  const _GearCandidateGrid({
    required this.slot,
    required this.candidates,
    required this.equippedId,
    required this.selectedId,
    required this.onSelected,
  });

  final GearSlot slot;
  final List<Object> candidates;
  final Object equippedId;
  final Object? selectedId;
  final ValueChanged<Object> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Unlocked',
          style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
        ),
        SizedBox(height: ui.space.sm),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: ui.space.sm,
            crossAxisSpacing: ui.space.sm,
            children: [
              for (final candidate in candidates)
                _GearCandidateTile(
                  slot: slot,
                  id: candidate,
                  isEquipped: candidate == equippedId,
                  selected: candidate == selectedId,
                  onTap: () => onSelected(candidate),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GearCandidateTile extends StatelessWidget {
  const _GearCandidateTile({
    required this.slot,
    required this.id,
    required this.isEquipped,
    required this.selected,
    required this.onTap,
  });

  final GearSlot slot;
  final Object id;
  final bool isEquipped;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : (isEquipped ? ui.colors.success : ui.colors.outline);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(4),
          alignment: Alignment.center,
          child: _GearIcon(slot: slot, id: id),
        ),
      ),
    );
  }
}

class _GearIcon extends StatelessWidget {
  const _GearIcon({required this.slot, required this.id});

  final GearSlot slot;
  final Object id;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    Widget child;
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        final weaponId = id as WeaponId;
        final coords = uiIconCoordsForWeapon(weaponId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords, backgroundColor: ui.colors.surface);
        break;
      case GearSlot.spellBook:
        final bookId = id as SpellBookId;
        final coords = uiIconCoordsForSpellBook(bookId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords, backgroundColor: ui.colors.surface);
        break;
      case GearSlot.accessory:
        final accessoryId = id as AccessoryId;
        final coords = uiIconCoordsForAccessory(accessoryId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords, backgroundColor: ui.colors.surface);
        break;
      case GearSlot.throwingWeapon:
        final itemId = id as ProjectileItemId;
        final path = throwingWeaponAssetPath(itemId);
        child = path == null
            ? const SizedBox.shrink()
            : Image.asset(path, width: 32, height: 32);
        break;
    }

    return SizedBox.square(dimension: 32, child: child);
  }
}

class _GearStatsCard extends StatelessWidget {
  const _GearStatsCard({
    required this.title,
    required this.slot,
    required this.id,
    this.equippedForCompare,
  });

  final String title;
  final GearSlot slot;
  final Object? id;
  final Object? equippedForCompare;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final lines = id == null ? const <_StatLine>[] : _statsFor(slot, id!);
    final compareLines = (id == null || equippedForCompare == null)
        ? const <_StatLine>[]
        : _compareStats(slot, equippedForCompare!, id!);

    return Container(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        boxShadow: ui.shadows.card,
      ),
      padding: EdgeInsets.all(ui.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ui.text.label),
          SizedBox(height: ui.space.xs),
          if (id == null)
            Text('Select an item', style: ui.text.body)
          else ...[
            Text(_titleFor(slot, id!), style: ui.text.headline),
            SizedBox(height: ui.space.xs),
            for (final line in lines) _StatLineText(line: line),
            if (compareLines.isNotEmpty) ...[
              SizedBox(height: ui.space.sm),
              Text('Compared', style: ui.text.label),
              SizedBox(height: ui.space.xs),
              for (final line in compareLines) _StatLineText(line: line),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatLine {
  const _StatLine(this.label, this.value);

  final String label;
  final String value;
}

class _StatLineText extends StatelessWidget {
  const _StatLineText({required this.line});

  final _StatLine line;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${line.label}: ${line.value}',
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      ),
    );
  }
}

String _titleFor(GearSlot slot, Object id) {
  return switch (slot) {
    GearSlot.mainWeapon || GearSlot.offhandWeapon => (id as WeaponId).name,
    GearSlot.throwingWeapon => (id as ProjectileItemId).name,
    GearSlot.spellBook => (id as SpellBookId).name,
    GearSlot.accessory => (id as AccessoryId).name,
  };
}

List<_StatLine> _statsFor(GearSlot slot, Object id) {
  switch (slot) {
    case GearSlot.mainWeapon:
    case GearSlot.offhandWeapon:
      final def = const WeaponCatalog().get(id as WeaponId);
      return _weaponDefStats(def);
    case GearSlot.throwingWeapon:
      final def = const ProjectileItemCatalog().get(id as ProjectileItemId);
      return _projectileItemStats(def);
    case GearSlot.spellBook:
      final def = const SpellBookCatalog().get(id as SpellBookId);
      return _spellBookStats(def);
    case GearSlot.accessory:
      final def = const AccessoryCatalog().get(id as AccessoryId);
      return _accessoryStats(def);
  }
}

List<_StatLine> _compareStats(
  GearSlot slot,
  Object equipped,
  Object candidate,
) {
  if (equipped == candidate) return const <_StatLine>[];
  switch (slot) {
    case GearSlot.mainWeapon:
    case GearSlot.offhandWeapon:
      final a = const WeaponCatalog().get(equipped as WeaponId);
      final b = const WeaponCatalog().get(candidate as WeaponId);
      return _diffWeaponStats(a, b);
    case GearSlot.throwingWeapon:
      final a = const ProjectileItemCatalog().get(equipped as ProjectileItemId);
      final b = const ProjectileItemCatalog().get(
        candidate as ProjectileItemId,
      );
      return _diffWeaponStatsLike(a.stats, b.stats);
    case GearSlot.spellBook:
      final a = const SpellBookCatalog().get(equipped as SpellBookId);
      final b = const SpellBookCatalog().get(candidate as SpellBookId);
      return _diffWeaponStatsLike(a.stats, b.stats);
    case GearSlot.accessory:
      final a = const AccessoryCatalog().get(equipped as AccessoryId);
      final b = const AccessoryCatalog().get(candidate as AccessoryId);
      return _diffAccessoryStats(a.stats, b.stats);
  }
}

List<_StatLine> _weaponDefStats(WeaponDef def) {
  final stats = def.stats;
  return <_StatLine>[
    _StatLine('Type', def.weaponType.name),
    _StatLine('Power', _bpPct(stats.powerBonusBp)),
    _StatLine('Crit Chance', _bpPct(stats.critChanceBonusBp)),
    _StatLine('Crit Damage', _bpPct(stats.critDamageBonusBp)),
    _StatLine('Range', '${stats.rangeScalarPercent}%'),
  ];
}

List<_StatLine> _projectileItemStats(ProjectileItemDef def) {
  final stats = def.stats;
  return <_StatLine>[
    _StatLine('Type', def.weaponType.name),
    _StatLine('Damage Type', def.damageType.name),
    _StatLine('Ballistic', def.ballistic ? 'Yes' : 'No'),
    _StatLine('Power', _bpPct(stats.powerBonusBp)),
    _StatLine('Crit Chance', _bpPct(stats.critChanceBonusBp)),
    _StatLine('Crit Damage', _bpPct(stats.critDamageBonusBp)),
  ];
}

List<_StatLine> _spellBookStats(SpellBookDef def) {
  final stats = def.stats;
  return <_StatLine>[
    _StatLine('Type', def.weaponType.name),
    _StatLine('Damage Type', def.damageType?.name ?? 'Ability'),
    _StatLine('Power', _bpPct(stats.powerBonusBp)),
    _StatLine('Crit Chance', _bpPct(stats.critChanceBonusBp)),
    _StatLine('Crit Damage', _bpPct(stats.critDamageBonusBp)),
  ];
}

List<_StatLine> _accessoryStats(AccessoryDef def) {
  final stats = def.stats;
  return <_StatLine>[
    _StatLine('HP', _pct100(stats.hpBonus100)),
    _StatLine('Mana', _pct100(stats.manaBonus100)),
    _StatLine('Stamina', _pct100(stats.staminaBonus100)),
    _StatLine('Move Speed', _bpPct(stats.moveSpeedBonusBp)),
    _StatLine('CDR', _bpPct(stats.cooldownReductionBp)),
  ];
}

List<_StatLine> _diffWeaponStats(WeaponDef equipped, WeaponDef candidate) {
  final a = equipped.stats;
  final b = candidate.stats;
  final lines = <_StatLine>[];
  if (b.powerBonusBp != a.powerBonusBp) {
    lines.add(_StatLine('Power', _deltaBpPct(a.powerBonusBp, b.powerBonusBp)));
  }
  if (b.critChanceBonusBp != a.critChanceBonusBp) {
    lines.add(
      _StatLine(
        'Crit Chance',
        _deltaBpPct(a.critChanceBonusBp, b.critChanceBonusBp),
      ),
    );
  }
  if (b.critDamageBonusBp != a.critDamageBonusBp) {
    lines.add(
      _StatLine(
        'Crit Damage',
        _deltaBpPct(a.critDamageBonusBp, b.critDamageBonusBp),
      ),
    );
  }
  if (b.rangeScalarPercent != a.rangeScalarPercent) {
    lines.add(
      _StatLine('Range', _deltaPct(a.rangeScalarPercent, b.rangeScalarPercent)),
    );
  }
  return lines;
}

List<_StatLine> _diffWeaponStatsLike(WeaponStats a, WeaponStats b) {
  final lines = <_StatLine>[];
  if (b.powerBonusBp != a.powerBonusBp) {
    lines.add(_StatLine('Power', _deltaBpPct(a.powerBonusBp, b.powerBonusBp)));
  }
  if (b.critChanceBonusBp != a.critChanceBonusBp) {
    lines.add(
      _StatLine(
        'Crit Chance',
        _deltaBpPct(a.critChanceBonusBp, b.critChanceBonusBp),
      ),
    );
  }
  if (b.critDamageBonusBp != a.critDamageBonusBp) {
    lines.add(
      _StatLine(
        'Crit Damage',
        _deltaBpPct(a.critDamageBonusBp, b.critDamageBonusBp),
      ),
    );
  }
  return lines;
}

List<_StatLine> _diffAccessoryStats(AccessoryStats a, AccessoryStats b) {
  final lines = <_StatLine>[];
  if (b.hpBonus100 != a.hpBonus100) {
    lines.add(_StatLine('HP', _deltaPct100(a.hpBonus100, b.hpBonus100)));
  }
  if (b.manaBonus100 != a.manaBonus100) {
    lines.add(_StatLine('Mana', _deltaPct100(a.manaBonus100, b.manaBonus100)));
  }
  if (b.staminaBonus100 != a.staminaBonus100) {
    lines.add(
      _StatLine('Stamina', _deltaPct100(a.staminaBonus100, b.staminaBonus100)),
    );
  }
  if (b.moveSpeedBonusBp != a.moveSpeedBonusBp) {
    lines.add(
      _StatLine(
        'Move Speed',
        _deltaBpPct(a.moveSpeedBonusBp, b.moveSpeedBonusBp),
      ),
    );
  }
  if (b.cooldownReductionBp != a.cooldownReductionBp) {
    lines.add(
      _StatLine(
        'CDR',
        _deltaBpPct(a.cooldownReductionBp, b.cooldownReductionBp),
      ),
    );
  }
  return lines;
}

String _bpPct(int bp) => '${(bp / 100).toStringAsFixed(2)}%';

String _pct100(int fixed100) => '${(fixed100 / 100).toStringAsFixed(2)}%';

String _deltaBpPct(int a, int b) {
  final delta = b - a;
  final sign = delta > 0 ? '+' : '';
  return '$sign${(delta / 100).toStringAsFixed(2)}%';
}

String _deltaPct100(int a, int b) {
  final delta = b - a;
  final sign = delta > 0 ? '+' : '';
  return '$sign${(delta / 100).toStringAsFixed(2)}%';
}

String _deltaPct(int a, int b) {
  final delta = b - a;
  final sign = delta > 0 ? '+' : '';
  return '$sign$delta%';
}
