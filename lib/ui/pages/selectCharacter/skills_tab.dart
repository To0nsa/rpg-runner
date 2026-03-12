import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../core/meta/ability_ownership_state.dart';
import '../../../core/players/player_character_definition.dart';
import '../../app/ui_routes.dart';
import '../../state/app_state.dart';
import '../../text/ability_tooltip_builder.dart';
import '../../theme/ui_tokens.dart';
import 'ability/ability_picker_presenter.dart';
import 'ability/ability_picker_shared.dart';
import 'skills/skills_details_pane.dart';
import 'skills/skills_list_pane.dart';
import 'skills/skills_projectile_source_dialog.dart';
import 'skills/skills_radial_pane.dart';

/// Selection-screen skills surface for one [PlayerCharacterId].
///
/// Keeps only ephemeral UI state locally (selected slot and inspected ability)
/// while persisting actual loadout changes through [AppState].
class SkillsBar extends StatefulWidget {
  const SkillsBar({super.key, required this.characterId});

  final PlayerCharacterId characterId;

  @override
  State<SkillsBar> createState() => _SkillsBarState();
}

class _SkillsBarState extends State<SkillsBar> {
  static const DefaultAbilityTooltipBuilder _tooltipBuilder =
      DefaultAbilityTooltipBuilder();

  AbilitySlot _selectedSlot = AbilitySlot.primary;
  AbilityKey? _inspectedAbilityId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final loadout = appState.selection.loadoutFor(widget.characterId);
    final availableSlots = _availableSlotsForMask(loadout.mask);
    final selectedSlot = _selectedSlotForBuild(availableSlots);
    final abilityOwnership = appState.meta.abilityOwnershipFor(
      widget.characterId,
    );
    final isProjectileSlot = selectedSlot == AbilitySlot.projectile;
    final selectedSourceSpellId = isProjectileSlot
        ? loadout.projectileSlotSpellId
        : null;
    final candidates = abilityCandidatesForSlot(
      characterId: widget.characterId,
      slot: selectedSlot,
      loadout: loadout,
      abilityOwnership: abilityOwnership,
      selectedSourceSpellId: selectedSourceSpellId,
      overrideSelectedSource: isProjectileSlot,
    );
    final equippedAbilityId = abilityIdForSlot(loadout, selectedSlot);
    final equippedAbilityIdsBySlot = <AbilitySlot, AbilityKey>{
      for (final slot in AbilitySlot.values)
        slot: abilityIdForSlot(loadout, slot),
    };
    final inspectedAbilityId = _resolveInspectedAbilityId(
      candidates,
      equippedAbilityId: equippedAbilityId,
    );
    final inspectedCandidate = _candidateById(candidates, inspectedAbilityId);
    final tooltip = inspectedCandidate == null || !inspectedCandidate.isOwned
        ? null
        : _tooltipBuilder.build(
            inspectedCandidate.def,
            ctx: AbilityTooltipContext(
              activeProjectileId: isProjectileSlot
                  ? selectedSourceSpellId
                  : null,
              payloadWeaponType: payloadWeaponTypeForTooltip(
                def: inspectedCandidate.def,
                slot: selectedSlot,
                selectedSourceSpellId: selectedSourceSpellId,
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(left: ui.space.xxs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _skillsLayoutForWidth(constraints.maxWidth);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: layout.listWidth,
                child: SkillsListPane(
                  selectedSlot: selectedSlot,
                  candidates: candidates,
                  selectedAbilityId: inspectedAbilityId,
                  onSelectAbility: (candidate) => _onSelectAbility(
                    appState: appState,
                    loadout: loadout,
                    candidate: candidate,
                    slot: selectedSlot,
                  ),
                  onSelectProjectileSource: isProjectileSlot
                      ? () => _showProjectileSourcePicker(
                          appState: appState,
                          loadout: loadout,
                          abilityOwnership: abilityOwnership,
                        )
                      : null,
                ),
              ),
              SizedBox(width: layout.gap),
              SizedBox(
                width: layout.detailsWidth,
                child: SkillsDetailsPane(
                  selectedCandidate: inspectedCandidate,
                  tooltip: tooltip,
                  onFindInTown: _openTownStoreFromLockedSkill,
                ),
              ),
              SizedBox(width: layout.gap),
              SizedBox(
                width: layout.radialWidth,
                child: SkillsRadialPane(
                  availableSlots: availableSlots,
                  selectedSlot: selectedSlot,
                  equippedAbilityIdsBySlot: equippedAbilityIdsBySlot,
                  onSelectSlot: _onSelectSlot,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onSelectSlot(AbilitySlot slot) {
    if (_selectedSlot == slot) return;
    setState(() {
      _selectedSlot = slot;
      _inspectedAbilityId = null;
    });
  }

  Future<void> _onSelectAbility({
    required AppState appState,
    required EquippedLoadoutDef loadout,
    required AbilityPickerCandidate candidate,
    required AbilitySlot slot,
  }) async {
    setState(() {
      _inspectedAbilityId = candidate.id;
    });
    if (!candidate.isOwned || !candidate.isEnabled) return;
    final equippedAbilityId = abilityIdForSlot(loadout, slot);
    if (equippedAbilityId == candidate.id) return;
    await appState.setAbilitySlot(
      characterId: widget.characterId,
      slot: slot,
      abilityId: candidate.id,
    );
  }

  AbilitySlot _selectedSlotForBuild(List<AbilitySlot> availableSlots) {
    if (availableSlots.isEmpty) return AbilitySlot.primary;
    if (availableSlots.contains(_selectedSlot)) return _selectedSlot;

    final fallback = availableSlots.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedSlot == fallback) return;
      setState(() {
        _selectedSlot = fallback;
        _inspectedAbilityId = null;
      });
    });
    return fallback;
  }

  Future<void> _showProjectileSourcePicker({
    required AppState appState,
    required EquippedLoadoutDef loadout,
    required AbilityOwnershipState abilityOwnership,
  }) {
    final options = projectileSourceOptions(loadout, abilityOwnership);
    return showProjectileSourceDialog(
      context,
      options: options,
      initialSelection: loadout.projectileSlotSpellId,
      onSelect: (sourceSpellId) async {
        await appState.setProjectileSpell(
          characterId: widget.characterId,
          spellId: sourceSpellId!,
        );
      },
    );
  }

  Future<void> _openTownStoreFromLockedSkill() {
    return Navigator.of(context).pushNamed(UiRoutes.town);
  }

  AbilityKey? _resolveInspectedAbilityId(
    List<AbilityPickerCandidate> candidates, {
    required AbilityKey equippedAbilityId,
  }) {
    if (candidates.isEmpty) return null;

    final inspected = _inspectedAbilityId;
    if (inspected != null) {
      for (final candidate in candidates) {
        if (candidate.id == inspected) return inspected;
      }
    }

    for (final candidate in candidates) {
      if (candidate.id == equippedAbilityId) return equippedAbilityId;
    }
    // Deterministic fallback keeps inspection stable when no equipped match.
    return candidates.first.id;
  }
}

List<AbilitySlot> _availableSlotsForMask(int mask) {
  final ordered = <AbilitySlot>[
    AbilitySlot.primary,
    AbilitySlot.secondary,
    AbilitySlot.projectile,
    AbilitySlot.mobility,
    AbilitySlot.spell,
    AbilitySlot.jump,
  ];
  return [
    for (final slot in ordered)
      if (_isSlotEnabledByMask(slot, mask)) slot,
  ];
}

bool _isSlotEnabledByMask(AbilitySlot slot, int mask) {
  switch (slot) {
    case AbilitySlot.primary:
      return (mask & LoadoutSlotMask.mainHand) != 0;
    case AbilitySlot.secondary:
      return (mask & LoadoutSlotMask.offHand) != 0;
    case AbilitySlot.projectile:
      return (mask & LoadoutSlotMask.projectile) != 0;
    case AbilitySlot.mobility:
    case AbilitySlot.spell:
    case AbilitySlot.jump:
      return true;
  }
}

@immutable
class _SkillsLayoutSpec {
  const _SkillsLayoutSpec({
    required this.listWidth,
    required this.detailsWidth,
    required this.radialWidth,
    required this.gap,
  });

  final double listWidth;
  final double detailsWidth;
  final double radialWidth;
  final double gap;
}

/// Computes side-panel widths for the skills screen at [width].
///
/// Uses tunable ratios across list, details, and radial columns.
_SkillsLayoutSpec _skillsLayoutForWidth(double width) {
  const gap = 8.0;
  const listRatio = 0.31;
  const detailsRatio = 0.44;
  const radialRatio = 0.25;
  const ratioTotal = listRatio + detailsRatio + radialRatio;
  final contentWidth = (width - (gap * 2))
      .clamp(0.0, double.infinity)
      .toDouble();
  final listWidth = contentWidth * (listRatio / ratioTotal);
  final detailsWidth = contentWidth * (detailsRatio / ratioTotal);
  final radialWidth = contentWidth * (radialRatio / ratioTotal);
  return _SkillsLayoutSpec(
    listWidth: listWidth,
    detailsWidth: detailsWidth,
    radialWidth: radialWidth,
    gap: gap,
  );
}

AbilityPickerCandidate? _candidateById(
  List<AbilityPickerCandidate> candidates,
  AbilityKey? id,
) {
  if (id == null) return null;
  for (final candidate in candidates) {
    if (candidate.id == id) return candidate;
  }
  return null;
}
