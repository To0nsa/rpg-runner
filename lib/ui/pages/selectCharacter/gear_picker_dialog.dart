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
import '../../components/app_button.dart';
import '../../icons/throwing_weapon_asset.dart';
import '../../icons/ui_icon_coords.dart';
import '../../icons/ui_icon_tile.dart';
import '../../state/app_state.dart';
import '../../text/gear_text.dart';
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
  void initState() {
    super.initState();
    _selectedCandidate = _equippedIdForSlot(
      widget.slot,
      widget.meta.equippedFor(widget.characterId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final inset = ui.space.sm;
    final maxDialogWidth = (screenSize.width - (inset * 2))
        .clamp(320.0, 1180.0)
        .toDouble();
    final maxDialogHeight = (screenSize.height - (inset * 2))
        .clamp(300.0, 700.0)
        .toDouble();
    final statsPanelWidth = (maxDialogWidth * 0.35)
        .clamp(240.0, 340.0)
        .toDouble();
    final paneSpacing = ui.space.sm;
    final appState = context.watch<AppState>();
    final equipped = widget.meta.equippedFor(widget.characterId);

    final equippedId = _equippedIdForSlot(widget.slot, equipped);
    final candidates = _candidatesForSlot(
      widget.slot,
      widget.service,
      widget.meta,
    );

    final selectedId = _selectedCandidate;
    final canSwap = selectedId != null && selectedId != equippedId;

    Future<void> equipSelected() async {
      final candidate = _selectedCandidate;
      if (candidate == null || candidate == equippedId) return;
      await appState.equipGear(
        characterId: widget.characterId,
        slot: widget.slot,
        itemId: candidate,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    return Dialog(
      backgroundColor: ui.colors.surface,
      insetPadding: EdgeInsets.all(inset),
      child: SizedBox(
        width: maxDialogWidth,
        height: maxDialogHeight,
        child: Padding(
          padding: EdgeInsets.all(ui.space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: statsPanelWidth,
                      child: _GearStatsCard(
                        title: 'Selected',
                        slot: widget.slot,
                        id: selectedId,
                        equippedForCompare: equippedId,
                      ),
                    ),
                    SizedBox(width: paneSpacing),
                    Expanded(
                      child: _GearCandidateGrid(
                        slot: widget.slot,
                        candidates: candidates,
                        equippedId: equippedId,
                        selectedId: selectedId,
                        onSelected: (value) =>
                            setState(() => _selectedCandidate = value),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: paneSpacing),
              _GearDialogActions(
                canEquip: canSwap,
                onClose: () => Navigator.of(context).pop(),
                onEquip: equipSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GearDialogActions extends StatelessWidget {
  const _GearDialogActions({
    required this.canEquip,
    required this.onClose,
    required this.onEquip,
  });

  final bool canEquip;
  final VoidCallback onClose;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: ui.space.sm,
        runSpacing: ui.space.xs,
        children: [
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.xs,
            onPressed: onClose,
          ),
          AppButton(
            label: 'Equip',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.xs,
            onPressed: canEquip ? onEquip : null,
          ),
        ],
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
    if (candidates.isEmpty) {
      return Center(
        child: Text(
          'No unlocked options for this slot.',
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = ui.space.xs;
        final gridSpec = _candidateGridSpecForAvailableSpace(
          itemCount: candidates.length,
          availableWidth: constraints.maxWidth,
          availableHeight: constraints.maxHeight,
          spacing: spacing,
        );

        return GridView.builder(
          itemCount: candidates.length,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSpec.crossAxisCount,
            mainAxisSpacing: gridSpec.spacing,
            crossAxisSpacing: gridSpec.spacing,
            mainAxisExtent: gridSpec.mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final candidate = candidates[index];
            return _GearCandidateTile(
              slot: slot,
              id: candidate,
              isEquipped: candidate == equippedId,
              selected: candidate == selectedId,
              onTap: () => onSelected(candidate),
            );
          },
        );
      },
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
    final title = gearDisplayNameForSlot(slot, id);
    final borderColor = selected
        ? ui.colors.accentStrong
        : (isEquipped ? ui.colors.success : ui.colors.outline);

    final fillColor = selected
        ? ui.colors.cardBackground.withValues(alpha: 0.9)
        : ui.colors.cardBackground.withValues(alpha: 0.72);
    final radius = ui.radii.sm;
    final tilePadding = 2.0;
    final iconFrameSize = 36.0;
    final titleMaxLines = 1;

    return Tooltip(
      message: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor,
                width: selected ? ui.sizes.borderWidth : 1,
              ),
              boxShadow: selected ? ui.shadows.card : null,
            ),
            padding: EdgeInsets.all(tilePadding),
            child: Column(
              children: [
                SizedBox(
                  height: 6,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEquipped) _StateDot(color: ui.colors.success),
                        if (isEquipped && selected) const SizedBox(width: 2),
                        if (selected) _StateDot(color: ui.colors.accentStrong),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Center(
                    child: Container(
                      width: iconFrameSize,
                      height: iconFrameSize,
                      decoration: BoxDecoration(
                        color: ui.colors.surface.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(ui.radii.sm),
                        border: Border.all(
                          color: ui.colors.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _GearIcon(slot: slot, id: id),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ui.text.caption.copyWith(
                    color: ui.colors.textPrimary,
                    fontSize: 9,
                    height: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _GearIcon extends StatelessWidget {
  const _GearIcon({required this.slot, required this.id});

  final GearSlot slot;
  final Object id;

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        final weaponId = id as WeaponId;
        final coords = uiIconCoordsForWeapon(weaponId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords);
        break;
      case GearSlot.spellBook:
        final bookId = id as SpellBookId;
        final coords = uiIconCoordsForSpellBook(bookId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords);
        break;
      case GearSlot.accessory:
        final accessoryId = id as AccessoryId;
        final coords = uiIconCoordsForAccessory(accessoryId);
        child = coords == null
            ? const SizedBox.shrink()
            : UiIconTile(coords: coords);
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
    final cardPadding = ui.space.xs;
    final iconFrameSize = 38.0;
    final blockSpacing = ui.space.xs;

    return Container(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.4)),
        boxShadow: ui.shadows.card,
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (id == null)
            Expanded(
              child: Center(
                child: Text(
                  'Select an item to preview stats.',
                  style: ui.text.caption.copyWith(color: ui.colors.textMuted),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: iconFrameSize,
                        height: iconFrameSize,
                        decoration: BoxDecoration(
                          color: ui.colors.surface.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(ui.radii.sm),
                          border: Border.all(
                            color: ui.colors.outline.withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _GearIcon(slot: slot, id: id!),
                      ),
                      SizedBox(width: ui.space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gearDisplayNameForSlot(slot, id!),
                              style: ui.text.caption.copyWith(
                                color: ui.colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '"${gearDescriptionForSlot(slot, id!)}"',
                              style: ui.text.caption.copyWith(
                                color: ui.colors.textMuted,
                                fontSize: 9,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: blockSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatSection(
                            title: 'Stats',
                            lines: lines,
                            emptyText: 'No non-zero stat bonuses.',
                          ),
                        ),
                        if (equippedForCompare != null) ...[
                          SizedBox(height: blockSpacing),
                          Expanded(
                            child: _StatSection(
                              title: 'Compared To Equipped',
                              lines: compareLines,
                              emptyText: 'No stat differences.',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  const _StatSection({
    required this.title,
    required this.lines,
    required this.emptyText,
  });

  final String title;
  final List<_StatLine> lines;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final sectionPadding = const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 4,
    );
    final headingStyle = ui.text.caption.copyWith(
      color: ui.colors.textMuted,
      fontWeight: FontWeight.w700,
      fontSize: 10,
      height: 1.0,
    );
    final emptyStyle = ui.text.caption.copyWith(
      color: ui.colors.textMuted,
      fontSize: 10,
      height: 1.0,
    );
    const interItemGap = 2.0;
    const estimatedRowHeight = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableForRows =
            constraints.maxHeight - sectionPadding.vertical - 10 - interItemGap;
        final maxRows = availableForRows.isFinite
            ? (availableForRows / estimatedRowHeight).floor()
            : lines.length;
        final safeMaxRows = maxRows < 1 ? 1 : maxRows;
        final visibleLines = lines.take(safeMaxRows).toList(growable: false);
        final hiddenLineCount = lines.length - visibleLines.length;

        return Container(
          width: double.infinity,
          padding: sectionPadding,
          decoration: BoxDecoration(
            color: ui.colors.surface.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(
              color: ui.colors.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: headingStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: interItemGap),
              if (lines.isEmpty)
                Text(
                  emptyText,
                  style: emptyStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else ...[
                for (final line in visibleLines) _StatLineText(line: line),
                if (hiddenLineCount > 0)
                  Text(
                    '+$hiddenLineCount more',
                    style: emptyStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _StatLineTone { neutral, positive, negative }

class _StatLine {
  const _StatLine(this.label, this.value, {this.tone = _StatLineTone.neutral});

  final String label;
  final String value;
  final _StatLineTone tone;
}

class _StatLineText extends StatelessWidget {
  const _StatLineText({required this.line});

  final _StatLine line;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final valueColor = switch (line.tone) {
      _StatLineTone.neutral => ui.colors.textPrimary,
      _StatLineTone.positive => ui.colors.success,
      _StatLineTone.negative => ui.colors.danger,
    };
    final labelStyle = ui.text.caption.copyWith(
      color: ui.colors.textMuted,
      fontSize: 10,
      height: 1.0,
    );
    final valueStyle = ui.text.caption.copyWith(
      color: valueColor,
      fontWeight: FontWeight.w600,
      fontSize: 10,
      height: 1.0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            line.value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CandidateGridSpec {
  const _CandidateGridSpec({
    required this.crossAxisCount,
    required this.mainAxisExtent,
    required this.spacing,
  });

  final int crossAxisCount;
  final double mainAxisExtent;
  final double spacing;
}

_CandidateGridSpec _candidateGridSpecForAvailableSpace({
  required int itemCount,
  required double availableWidth,
  required double availableHeight,
  required double spacing,
}) {
  if (itemCount <= 0 || availableWidth <= 0 || availableHeight <= 0) {
    return _CandidateGridSpec(
      crossAxisCount: 1,
      mainAxisExtent: 64,
      spacing: spacing,
    );
  }

  const minTileWidth = 64.0;
  const minTileHeight = 58.0;
  const maxTileHeight = 88.0;
  final maxColumnsByWidth =
      ((availableWidth + spacing) / (minTileWidth + spacing)).floor().clamp(
        1,
        itemCount,
      );

  var selectedColumns = 1;
  var selectedHeight = minTileHeight;
  for (var columns = maxColumnsByWidth; columns >= 1; columns--) {
    final rows = (itemCount + columns - 1) ~/ columns;
    final tileWidth = (availableWidth - spacing * (columns - 1)) / columns;
    final targetTileHeight = (tileWidth * 0.84)
        .clamp(minTileHeight, maxTileHeight)
        .toDouble();
    final totalHeight = rows * targetTileHeight + spacing * (rows - 1);
    if (totalHeight <= availableHeight) {
      selectedColumns = columns;
      selectedHeight = targetTileHeight;
      break;
    }
  }

  final rows = (itemCount + selectedColumns - 1) ~/ selectedColumns;
  final fittedHeight = ((availableHeight - spacing * (rows - 1)) / rows)
      .clamp(40.0, maxTileHeight)
      .toDouble();
  final resolvedHeight = selectedHeight.clamp(40.0, fittedHeight).toDouble();

  return _CandidateGridSpec(
    crossAxisCount: selectedColumns,
    mainAxisExtent: resolvedHeight,
    spacing: spacing,
  );
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
  final lines = <_StatLine>[_StatLine('Type', _enumLabel(def.weaponType.name))];
  _addBpStat(lines, 'Power', stats.powerBonusBp);
  _addBpStat(lines, 'Crit Chance', stats.critChanceBonusBp);
  _addBpStat(lines, 'Crit Damage', stats.critDamageBonusBp);
  _addIntPercentStat(lines, 'Range', stats.rangeScalarPercent);
  return lines;
}

List<_StatLine> _projectileItemStats(ProjectileItemDef def) {
  final stats = def.stats;
  final lines = <_StatLine>[
    _StatLine('Type', _enumLabel(def.weaponType.name)),
    _StatLine('Damage Type', _enumLabel(def.damageType.name)),
    _StatLine('Ballistic', def.ballistic ? 'Yes' : 'No'),
  ];
  _addBpStat(lines, 'Power', stats.powerBonusBp);
  _addBpStat(lines, 'Crit Chance', stats.critChanceBonusBp);
  _addBpStat(lines, 'Crit Damage', stats.critDamageBonusBp);
  return lines;
}

List<_StatLine> _spellBookStats(SpellBookDef def) {
  final stats = def.stats;
  final lines = <_StatLine>[
    _StatLine('Type', _enumLabel(def.weaponType.name)),
    _StatLine(
      'Damage Type',
      def.damageType == null ? 'Ability' : _enumLabel(def.damageType!.name),
    ),
  ];
  _addBpStat(lines, 'Power', stats.powerBonusBp);
  _addBpStat(lines, 'Crit Chance', stats.critChanceBonusBp);
  _addBpStat(lines, 'Crit Damage', stats.critDamageBonusBp);
  return lines;
}

List<_StatLine> _accessoryStats(AccessoryDef def) {
  final stats = def.stats;
  final lines = <_StatLine>[];
  _addPct100Stat(lines, 'HP', stats.hpBonus100);
  _addPct100Stat(lines, 'Mana', stats.manaBonus100);
  _addPct100Stat(lines, 'Stamina', stats.staminaBonus100);
  _addBpStat(lines, 'Move Speed', stats.moveSpeedBonusBp);
  _addBpStat(lines, 'CDR', stats.cooldownReductionBp);
  return lines;
}

void _addBpStat(List<_StatLine> lines, String label, int value) {
  if (value == 0) return;
  lines.add(_StatLine(label, _bpPct(value)));
}

void _addPct100Stat(List<_StatLine> lines, String label, int value) {
  if (value == 0) return;
  lines.add(_StatLine(label, _pct100(value)));
}

void _addIntPercentStat(List<_StatLine> lines, String label, int value) {
  if (value == 0) return;
  lines.add(_StatLine(label, '$value%'));
}

List<_StatLine> _diffWeaponStats(WeaponDef equipped, WeaponDef candidate) {
  final a = equipped.stats;
  final b = candidate.stats;
  final lines = <_StatLine>[];
  if (b.powerBonusBp != a.powerBonusBp) {
    lines.add(_deltaBpLine('Power', a.powerBonusBp, b.powerBonusBp));
  }
  if (b.critChanceBonusBp != a.critChanceBonusBp) {
    lines.add(
      _deltaBpLine('Crit Chance', a.critChanceBonusBp, b.critChanceBonusBp),
    );
  }
  if (b.critDamageBonusBp != a.critDamageBonusBp) {
    lines.add(
      _deltaBpLine('Crit Damage', a.critDamageBonusBp, b.critDamageBonusBp),
    );
  }
  if (b.rangeScalarPercent != a.rangeScalarPercent) {
    lines.add(
      _deltaIntPercentLine('Range', a.rangeScalarPercent, b.rangeScalarPercent),
    );
  }
  return lines;
}

List<_StatLine> _diffWeaponStatsLike(WeaponStats a, WeaponStats b) {
  final lines = <_StatLine>[];
  if (b.powerBonusBp != a.powerBonusBp) {
    lines.add(_deltaBpLine('Power', a.powerBonusBp, b.powerBonusBp));
  }
  if (b.critChanceBonusBp != a.critChanceBonusBp) {
    lines.add(
      _deltaBpLine('Crit Chance', a.critChanceBonusBp, b.critChanceBonusBp),
    );
  }
  if (b.critDamageBonusBp != a.critDamageBonusBp) {
    lines.add(
      _deltaBpLine('Crit Damage', a.critDamageBonusBp, b.critDamageBonusBp),
    );
  }
  return lines;
}

List<_StatLine> _diffAccessoryStats(AccessoryStats a, AccessoryStats b) {
  final lines = <_StatLine>[];
  if (b.hpBonus100 != a.hpBonus100) {
    lines.add(_deltaPct100Line('HP', a.hpBonus100, b.hpBonus100));
  }
  if (b.manaBonus100 != a.manaBonus100) {
    lines.add(_deltaPct100Line('Mana', a.manaBonus100, b.manaBonus100));
  }
  if (b.staminaBonus100 != a.staminaBonus100) {
    lines.add(
      _deltaPct100Line('Stamina', a.staminaBonus100, b.staminaBonus100),
    );
  }
  if (b.moveSpeedBonusBp != a.moveSpeedBonusBp) {
    lines.add(
      _deltaBpLine('Move Speed', a.moveSpeedBonusBp, b.moveSpeedBonusBp),
    );
  }
  if (b.cooldownReductionBp != a.cooldownReductionBp) {
    lines.add(
      _deltaBpLine('CDR', a.cooldownReductionBp, b.cooldownReductionBp),
    );
  }
  return lines;
}

_StatLine _deltaBpLine(String label, int equippedValue, int candidateValue) {
  final delta = candidateValue - equippedValue;
  return _StatLine(
    label,
    _signedPercent(delta / 100),
    tone: _toneForDelta(delta),
  );
}

_StatLine _deltaPct100Line(
  String label,
  int equippedValue,
  int candidateValue,
) {
  final delta = candidateValue - equippedValue;
  return _StatLine(
    label,
    _signedPercent(delta / 100),
    tone: _toneForDelta(delta),
  );
}

_StatLine _deltaIntPercentLine(
  String label,
  int equippedValue,
  int candidateValue,
) {
  final delta = candidateValue - equippedValue;
  final sign = delta > 0 ? '+' : '';
  return _StatLine(label, '$sign$delta%', tone: _toneForDelta(delta));
}

_StatLineTone _toneForDelta(int delta) {
  if (delta > 0) return _StatLineTone.positive;
  if (delta < 0) return _StatLineTone.negative;
  return _StatLineTone.neutral;
}

String _bpPct(int bp) => '${_formatNumber(bp / 100)}%';

String _pct100(int fixed100) => '${_formatNumber(fixed100 / 100)}%';

String _signedPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_formatNumber(value)}%';
}

String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _enumLabel(String source) {
  final normalized = source.replaceAll('_', ' ');
  final words = normalized.split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
