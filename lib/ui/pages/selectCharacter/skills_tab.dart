import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../components/app_button.dart';
import '../../state/app_state.dart';
import '../../text/ability_tooltip_builder.dart';
import '../../theme/ui_tokens.dart';
import 'ability/ability_picker_presenter.dart';
import 'ability/ability_picker_shared.dart';
import 'skills/skills_details_pane.dart';
import 'skills/skills_list_pane.dart';
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
    final rawLoadout = appState.selection.loadoutFor(widget.characterId);
    final loadout = normalizeLoadoutMaskForCharacter(
      characterId: widget.characterId,
      loadout: rawLoadout,
    );
    final isProjectileSlot = _selectedSlot == AbilitySlot.projectile;
    final selectedSourceSpellId = isProjectileSlot
        ? loadout.projectileSlotSpellId
        : null;
    final candidates = abilityCandidatesForSlot(
      characterId: widget.characterId,
      slot: _selectedSlot,
      loadout: loadout,
      selectedSourceSpellId: selectedSourceSpellId,
      overrideSelectedSource: isProjectileSlot,
    );
    final equippedAbilityId = abilityIdForSlot(loadout, _selectedSlot);
    final inspectedAbilityId = _resolveInspectedAbilityId(
      candidates,
      equippedAbilityId: equippedAbilityId,
    );
    final inspectedCandidate = _candidateById(candidates, inspectedAbilityId);
    final tooltip = inspectedCandidate == null
        ? null
        : _tooltipBuilder.build(
            inspectedCandidate.def,
            ctx: AbilityTooltipContext(
              selectedProjectileSpellId: isProjectileSlot
                  ? selectedSourceSpellId
                  : null,
              payloadWeaponType: payloadWeaponTypeForTooltip(
                def: inspectedCandidate.def,
                slot: _selectedSlot,
                selectedSourceSpellId: selectedSourceSpellId,
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(left: ui.space.xxs, top: ui.space.xxs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _skillsLayoutForWidth(constraints.maxWidth);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: layout.listWidth,
                child: SkillsListPane(
                  selectedSlot: _selectedSlot,
                  candidates: candidates,
                  selectedAbilityId: inspectedAbilityId,
                  panePadding: ui.space.xs,
                  sectionSpacing: ui.space.xxs,
                  titleStyle: ui.text.body.copyWith(
                    color: ui.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  tileHorizontalPadding: ui.space.xs,
                  tileVerticalPadding: ui.space.xxs,
                  onSelectAbility: (candidate) => _onSelectAbility(
                    appState: appState,
                    loadout: loadout,
                    candidate: candidate,
                  ),
                  onSelectProjectileSource: isProjectileSlot
                      ? () => _showProjectileSourcePicker(
                          appState: appState,
                          loadout: loadout,
                        )
                      : null,
                ),
              ),
              SizedBox(width: layout.gap),
              Expanded(child: SkillsDetailsPane(tooltip: tooltip)),
              SizedBox(width: layout.gap),
              SizedBox(
                width: layout.radialWidth,
                child: SkillsRadialPane(
                  selectedSlot: _selectedSlot,
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
  }) async {
    setState(() {
      _inspectedAbilityId = candidate.id;
    });
    if (!candidate.isEnabled) return;
    final equippedAbilityId = abilityIdForSlot(loadout, _selectedSlot);
    if (equippedAbilityId == candidate.id) return;
    final next = setAbilityForSlot(
      loadout,
      slot: _selectedSlot,
      abilityId: candidate.id,
    );
    await appState.setLoadout(next);
  }

  Future<void> _showProjectileSourcePicker({
    required AppState appState,
    required EquippedLoadoutDef loadout,
  }) {
    final options = projectileSourceOptions(loadout);
    final selectedSource = loadout.projectileSlotSpellId;
    return showDialog<void>(
      context: context,
      barrierColor: context.ui.colors.scrim,
      builder: (dialogContext) {
        final ui = dialogContext.ui;
        final media = MediaQuery.of(dialogContext);
        final maxWidth = (media.size.width - (ui.space.sm * 2))
            .clamp(320.0, 460.0)
            .toDouble();
        final maxHeight = (media.size.height - (ui.space.sm * 2))
            .clamp(220.0, 520.0)
            .toDouble();

        Future<void> selectSource(ProjectileId? sourceSpellId) async {
          final next = setProjectileSourceForSlot(
            loadout,
            slot: AbilitySlot.projectile,
            selectedSpellId: sourceSpellId,
          );
          await appState.setLoadout(next);
          // Guard against async completion after the dialog tree is disposed.
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
        }

        return Dialog(
          backgroundColor: const Color(0xFF0D0D0D),
          insetPadding: EdgeInsets.all(ui.space.sm),
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
                  Text(
                    'Select Projectile Source',
                    style: ui.text.headline.copyWith(
                      color: ui.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: ui.space.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) => SizedBox(height: ui.space.xs),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option.spellId == selectedSource;
                        return SkillsProjectileSourceTile(
                          title: option.displayName,
                          selected: selected,
                          onTap: () => selectSource(option.spellId),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: ui.space.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      label: 'Close',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.xs,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

@immutable
class _SkillsLayoutSpec {
  const _SkillsLayoutSpec({
    required this.listWidth,
    required this.radialWidth,
    required this.gap,
  });

  final double listWidth;
  final double radialWidth;
  final double gap;
}

/// Computes side-panel widths for the skills screen at [width].
///
/// Guarantees a minimum center pane width so details remain readable.
_SkillsLayoutSpec _skillsLayoutForWidth(double width) {
  final gap = width < 420 ? 4.0 : (width < 760 ? 6.0 : 10.0);
  var listWidth = (width * (width < 760 ? 0.33 : 0.30))
      .clamp(100.0, 300.0)
      .toDouble();
  var radialWidth = (width * (width < 760 ? 0.28 : 0.26))
      .clamp(84.0, 240.0)
      .toDouble();
  final minMiddle = width < 760 ? 120.0 : 210.0;
  final maxSideTotal = math.max(140.0, width - minMiddle - (gap * 2));
  final sideTotal = listWidth + radialWidth;
  if (sideTotal > maxSideTotal) {
    final scale = maxSideTotal / sideTotal;
    listWidth *= scale;
    radialWidth *= scale;
  }
  return _SkillsLayoutSpec(
    listWidth: listWidth,
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
