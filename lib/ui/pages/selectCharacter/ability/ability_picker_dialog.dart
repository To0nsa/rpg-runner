import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/abilities/ability_def.dart';
import '../../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../../core/meta/gear_slot.dart';
import '../../../../core/players/player_character_definition.dart';
import '../../../../core/projectiles/projectile_id.dart';
import '../../../components/ability_placeholder_icon.dart';
import '../../../components/app_button.dart';
import '../../../components/gear_icon.dart';
import '../../../state/app_state.dart';
import '../../../text/ability_tooltip_builder.dart';
import '../../../theme/ui_tokens.dart';
import 'ability_picker_presenter.dart';

/// Opens a slot picker dialog for one action [slot].
Future<void> showAbilityPickerDialog(
  BuildContext context, {
  required PlayerCharacterId characterId,
  required AbilitySlot slot,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: context.ui.colors.scrim,
    builder: (dialogContext) =>
        _AbilityPickerDialog(characterId: characterId, slot: slot),
  );
}

class _AbilityPickerDialog extends StatefulWidget {
  const _AbilityPickerDialog({required this.characterId, required this.slot});

  final PlayerCharacterId characterId;
  final AbilitySlot slot;

  @override
  State<_AbilityPickerDialog> createState() => _AbilityPickerDialogState();
}

class _AbilityPickerDialogState extends State<_AbilityPickerDialog> {
  late AbilityKey _selectedAbilityId;
  ProjectileId? _selectedSourceSpellId;
  bool _spellBookExpanded = false;
  bool _seeded = false;

  bool get _showsProjectileSourcePanel => widget.slot == AbilitySlot.projectile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final selection = context.read<AppState>().selection;
    final loadout = selection.loadoutFor(widget.characterId);
    _selectedAbilityId = abilityIdForSlot(loadout, widget.slot);
    _selectedSourceSpellId = _initialSourceSpellId(loadout, widget.slot);
    _spellBookExpanded = _selectedSourceSpellId != null;
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final media = MediaQuery.of(context);
    final appState = context.watch<AppState>();
    final rawLoadout = appState.selection.loadoutFor(widget.characterId);
    final loadout = normalizeLoadoutMaskForCharacter(
      characterId: widget.characterId,
      loadout: rawLoadout,
    );
    final sourceModel = _showsProjectileSourcePanel
        ? projectileSourcePanelModel(loadout)
        : null;
    final normalizedSource = _showsProjectileSourcePanel
        ? normalizeProjectileSourceSelection(loadout, _selectedSourceSpellId)
        : null;

    if (_showsProjectileSourcePanel &&
        _selectedSourceSpellId != normalizedSource) {
      _selectedSourceSpellId = normalizedSource;
      _spellBookExpanded = normalizedSource != null;
    }

    final candidates = abilityCandidatesForSlot(
      characterId: widget.characterId,
      slot: widget.slot,
      loadout: loadout,
      selectedSourceSpellId: _selectedSourceSpellId,
      overrideSelectedSource: _showsProjectileSourcePanel,
    );
    AbilityPickerCandidate? selectedCandidate;
    for (final candidate in candidates) {
      if (candidate.id == _selectedAbilityId) {
        selectedCandidate = candidate;
        break;
      }
    }
    final selectedEnabled = selectedCandidate?.isEnabled ?? false;

    final initialAbilityId = abilityIdForSlot(loadout, widget.slot);
    final initialSourceId = _initialSourceSpellId(loadout, widget.slot);
    final isDirty =
        _selectedAbilityId != initialAbilityId ||
        (_showsProjectileSourcePanel &&
            _selectedSourceSpellId != initialSourceId);
    final canApply = isDirty && selectedEnabled;

    final inset = ui.space.sm;
    final maxWidth = (media.size.width - (inset * 2))
        .clamp(360.0, _showsProjectileSourcePanel ? 980.0 : 760.0)
        .toDouble();
    final maxHeight = (media.size.height - (inset * 2))
        .clamp(280.0, 620.0)
        .toDouble();

    Future<void> applySelection() async {
      if (!canApply) return;
      var next = setAbilityForSlot(
        loadout,
        slot: widget.slot,
        abilityId: _selectedAbilityId,
      );
      if (_showsProjectileSourcePanel) {
        next = setProjectileSourceForSlot(
          next,
          slot: widget.slot,
          selectedSpellId: _selectedSourceSpellId,
        );
      }
      await appState.setLoadout(next);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    return Dialog(
      backgroundColor: const Color(0xFF0D0D0D),
      insetPadding: EdgeInsets.all(inset),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.md),
        side: BorderSide(color: ui.colors.outline.withValues(alpha: 0.35)),
      ),
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: Padding(
          padding: EdgeInsets.all(ui.space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(slot: widget.slot),
              SizedBox(height: ui.space.sm),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showsProjectileSourcePanel) ...[
                      SizedBox(
                        width: 230,
                        child: _SourcePanel(
                          sourceModel: sourceModel!,
                          selectedSpellId: _selectedSourceSpellId,
                          spellBookExpanded: _spellBookExpanded,
                          onSelectThrowingWeapon: () =>
                              _selectSource(loadout: loadout, spellId: null),
                          onToggleSpellBook: () {
                            setState(() {
                              _spellBookExpanded = !_spellBookExpanded;
                            });
                          },
                          onSelectSpell: (spellId) =>
                              _selectSource(loadout: loadout, spellId: spellId),
                        ),
                      ),
                      SizedBox(width: ui.space.sm),
                    ],
                    Expanded(
                      child: _AbilityPanel(
                        slot: widget.slot,
                        selectedSourceSpellId: _selectedSourceSpellId,
                        candidates: candidates,
                        selectedAbilityId: _selectedAbilityId,
                        onSelected: (id) =>
                            setState(() => _selectedAbilityId = id),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ui.space.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: ui.space.sm,
                  children: [
                    AppButton(
                      label: 'Close',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.xs,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    AppButton(
                      label: 'Apply',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.xs,
                      onPressed: canApply ? applySelection : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectSource({
    required EquippedLoadoutDef loadout,
    required ProjectileId? spellId,
  }) {
    setState(() {
      _selectedSourceSpellId = spellId;
      _spellBookExpanded = spellId != null;
      final refreshed = abilityCandidatesForSlot(
        characterId: widget.characterId,
        slot: widget.slot,
        loadout: loadout,
        selectedSourceSpellId: spellId,
        overrideSelectedSource: true,
      );
      final currentEnabled = refreshed.any(
        (candidate) =>
            candidate.id == _selectedAbilityId && candidate.isEnabled,
      );
      if (!currentEnabled) {
        final fallback = refreshed.firstWhere(
          (candidate) => candidate.isEnabled,
          orElse: () => refreshed.first,
        );
        _selectedAbilityId = fallback.id;
      }
    });
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.slot});

  final AbilitySlot slot;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Text(
      _slotTitle(slot),
      style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({
    required this.sourceModel,
    required this.selectedSpellId,
    required this.spellBookExpanded,
    required this.onSelectThrowingWeapon,
    required this.onToggleSpellBook,
    required this.onSelectSpell,
  });

  final ProjectileSourcePanelModel sourceModel;
  final ProjectileId? selectedSpellId;
  final bool spellBookExpanded;
  final VoidCallback onSelectThrowingWeapon;
  final VoidCallback onToggleSpellBook;
  final ValueChanged<ProjectileId> onSelectSpell;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return _PanelFrame(
      title: 'Projectile Source',
      child: ListView(
        children: [
          _SourceSelectableTile(
            selected: selectedSpellId == null,
            highlighted: selectedSpellId == null,
            title: sourceModel.throwingWeaponDisplayName,
            subtitle: 'Throwing weapon',
            leading: GearIcon(
              slot: GearSlot.throwingWeapon,
              id: sourceModel.throwingWeaponId,
              size: 24,
            ),
            onTap: onSelectThrowingWeapon,
          ),
          SizedBox(height: ui.space.xs),
          _SourceSelectableTile(
            selected: selectedSpellId != null,
            highlighted: spellBookExpanded || selectedSpellId != null,
            title: sourceModel.spellBookDisplayName,
            subtitle: 'Spellbook',
            leading: GearIcon(
              slot: GearSlot.spellBook,
              id: sourceModel.spellBookId,
              size: 24,
            ),
            trailing: Icon(
              spellBookExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: ui.colors.textMuted,
            ),
            onTap: onToggleSpellBook,
          ),
          if (spellBookExpanded) ...[
            SizedBox(height: ui.space.xs),
            Padding(
              padding: EdgeInsets.only(left: ui.space.sm),
              child: Column(
                children: sourceModel.spellOptions.isEmpty
                    ? [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: ui.space.sm,
                            vertical: ui.space.xs,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(ui.radii.sm),
                            border: Border.all(
                              color: ui.colors.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'No spell projectiles available',
                            style: ui.text.caption.copyWith(
                              color: ui.colors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]
                    : [
                        for (
                          var i = 0;
                          i < sourceModel.spellOptions.length;
                          i++
                        ) ...[
                          _SourceSelectableTile(
                            selected:
                                selectedSpellId ==
                                sourceModel.spellOptions[i].spellId,
                            highlighted:
                                selectedSpellId ==
                                sourceModel.spellOptions[i].spellId,
                            title: sourceModel.spellOptions[i].displayName,
                            subtitle: 'Spell projectile',
                            leading: AbilityPlaceholderIcon(
                              label: _placeholderLabel(
                                sourceModel.spellOptions[i].displayName,
                              ),
                              size: 20,
                              emphasis:
                                  selectedSpellId ==
                                  sourceModel.spellOptions[i].spellId,
                            ),
                            onTap: () => onSelectSpell(
                              sourceModel.spellOptions[i].spellId,
                            ),
                          ),
                          if (i < sourceModel.spellOptions.length - 1)
                            SizedBox(height: ui.space.xs),
                        ],
                      ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceSelectableTile extends StatelessWidget {
  const _SourceSelectableTile({
    required this.selected,
    required this.highlighted,
    required this.title,
    required this.subtitle,
    required this.leading,
    this.trailing,
    required this.onTap,
  });

  final bool selected;
  final bool highlighted;
  final String title;
  final String subtitle;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = highlighted
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = highlighted
        ? const Color(0xFF1A1A1A)
        : const Color(0xFF131313);
    final subtitleColor = selected
        ? ui.colors.textPrimary
        : ui.colors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ui.space.sm,
            vertical: ui.space.xs,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(ui.radii.sm),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              leading,
              SizedBox(width: ui.space.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ui.text.body.copyWith(
                        color: ui.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ui.space.xxs),
                    Text(
                      subtitle,
                      style: ui.text.caption.copyWith(
                        color: subtitleColor,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: ui.space.xs),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AbilityPanel extends StatelessWidget {
  const _AbilityPanel({
    required this.slot,
    required this.selectedSourceSpellId,
    required this.candidates,
    required this.selectedAbilityId,
    required this.onSelected,
  });

  static const DefaultAbilityTooltipBuilder _tooltipBuilder =
      DefaultAbilityTooltipBuilder();

  final AbilitySlot slot;
  final ProjectileId? selectedSourceSpellId;
  final List<AbilityPickerCandidate> candidates;
  final AbilityKey selectedAbilityId;
  final ValueChanged<AbilityKey> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return _PanelFrame(
      title: 'Ability',
      child: ListView.separated(
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          final selected = candidate.id == selectedAbilityId;
          final tooltip = _tooltipBuilder.build(
            candidate.def,
            ctx: AbilityTooltipContext(
              selectedProjectileSpellId: slot == AbilitySlot.projectile
                  ? selectedSourceSpellId
                  : null,
              payloadWeaponType: _payloadWeaponTypeForTooltip(
                def: candidate.def,
                slot: slot,
                selectedSourceSpellId: selectedSourceSpellId,
              ),
            ),
          );
          return _SelectableTile(
            selected: selected,
            enabled: candidate.isEnabled,
            title: tooltip.title,
            subtitle: tooltip.subtitle,
            onTap: candidate.isEnabled ? () => onSelected(candidate.id) : null,
          );
        },
        separatorBuilder: (_, _) => SizedBox(height: ui.space.xs),
      ),
    );
  }
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(ui.space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ui.text.caption.copyWith(
              color: ui.colors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: ui.space.xs),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = selected
        ? const Color(0xFF1A1A1A)
        : const Color(0xFF131313);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui.radii.sm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ui.space.sm,
              vertical: ui.space.xs,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AbilityPlaceholderIcon(
                      label: _placeholderLabel(title),
                      size: 20,
                      emphasis: selected,
                      enabled: enabled,
                    ),
                    SizedBox(width: ui.space.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: ui.text.body.copyWith(
                              color: ui.colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ui.space.xxs),
                          Text(
                            subtitle,
                            style: ui.text.caption.copyWith(
                              color: ui.colors.textMuted,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ProjectileId? _initialSourceSpellId(
  EquippedLoadoutDef loadout,
  AbilitySlot slot,
) {
  switch (slot) {
    case AbilitySlot.projectile:
      return loadout.projectileSlotSpellId;
    case AbilitySlot.primary:
    case AbilitySlot.secondary:
    case AbilitySlot.spell:
    case AbilitySlot.mobility:
    case AbilitySlot.jump:
      return null;
  }
}

String _slotTitle(AbilitySlot slot) {
  switch (slot) {
    case AbilitySlot.primary:
      return 'Primary Slot';
    case AbilitySlot.secondary:
      return 'Secondary Slot';
    case AbilitySlot.projectile:
      return 'Range Slot';
    case AbilitySlot.mobility:
      return 'Mobility Slot';
    case AbilitySlot.spell:
      return 'Spell Slot';
    case AbilitySlot.jump:
      return 'Jump Slot';
  }
}

WeaponType? _payloadWeaponTypeForTooltip({
  required AbilityDef def,
  required AbilitySlot slot,
  required ProjectileId? selectedSourceSpellId,
}) {
  switch (def.payloadSource) {
    case AbilityPayloadSource.none:
      return null;
    case AbilityPayloadSource.primaryWeapon:
      return null;
    case AbilityPayloadSource.secondaryWeapon:
      return null;
    case AbilityPayloadSource.projectile:
      if (slot == AbilitySlot.projectile && selectedSourceSpellId != null) {
        return WeaponType.projectileSpell;
      }
      return WeaponType.throwingWeapon;
    case AbilityPayloadSource.spellBook:
      return WeaponType.projectileSpell;
  }
}

String _placeholderLabel(String text) {
  final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  final buffer = StringBuffer();
  for (final word in words) {
    buffer.write(word[0].toUpperCase());
    if (buffer.length >= 2) break;
  }
  final value = buffer.toString();
  return value.isEmpty ? '?' : value;
}
