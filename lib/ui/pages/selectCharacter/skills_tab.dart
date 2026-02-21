import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../components/ability_placeholder_icon.dart';
import '../../components/app_button.dart';
import '../../controls/action_button.dart';
import '../../controls/ability_slot_visual_spec.dart';
import '../../controls/controls_tuning.dart';
import '../../controls/layout/controls_radial_layout.dart';
import '../../state/app_state.dart';
import '../../text/ability_text.dart';
import '../../text/ability_tooltip_builder.dart';
import '../../theme/ui_tokens.dart';
import 'ability/ability_picker_presenter.dart';

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
    final selectedSourceSpellId = _selectedSlot == AbilitySlot.projectile
        ? loadout.projectileSlotSpellId
        : null;
    final candidates = abilityCandidatesForSlot(
      characterId: widget.characterId,
      slot: _selectedSlot,
      loadout: loadout,
      selectedSourceSpellId: selectedSourceSpellId,
      overrideSelectedSource: _selectedSlot == AbilitySlot.projectile,
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
              selectedProjectileSpellId: _selectedSlot == AbilitySlot.projectile
                  ? selectedSourceSpellId
                  : null,
              payloadWeaponType: _payloadWeaponTypeForTooltip(
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
                child: _SkillsListPane(
                  selectedSlot: _selectedSlot,
                  candidates: candidates,
                  selectedAbilityId: inspectedAbilityId,
                  compact: layout.compact,
                  onSelectAbility: (candidate) => _onSelectAbility(
                    appState: appState,
                    loadout: loadout,
                    candidate: candidate,
                  ),
                  onSelectProjectileSource:
                      _selectedSlot == AbilitySlot.projectile
                      ? () => _showProjectileSourcePicker(
                          appState: appState,
                          loadout: loadout,
                        )
                      : null,
                ),
              ),
              SizedBox(width: layout.gap),
              Expanded(
                child: _SkillsDetailsPane(
                  slot: _selectedSlot,
                  candidate: inspectedCandidate,
                  tooltip: tooltip,
                ),
              ),
              SizedBox(width: layout.gap),
              SizedBox(
                width: layout.radialWidth,
                child: _SkillsRadialPane(
                  characterId: widget.characterId,
                  selectedSlot: _selectedSlot,
                  onSelectSlot: _onSelectSlot,
                  compact: layout.compact,
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
                        return _ProjectileSourceTile(
                          title: option.displayName,
                          subtitle: option.isSpell
                              ? 'Spell projectile'
                              : 'Throwing weapon',
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
    return candidates.first.id;
  }
}

@immutable
class _SkillsLayoutSpec {
  const _SkillsLayoutSpec({
    required this.listWidth,
    required this.radialWidth,
    required this.gap,
    required this.compact,
  });

  final double listWidth;
  final double radialWidth;
  final double gap;
  final bool compact;
}

_SkillsLayoutSpec _skillsLayoutForWidth(double width) {
  final compact = width < 760;
  final gap = width < 420 ? 4.0 : (compact ? 6.0 : 10.0);
  var listWidth = (width * (compact ? 0.33 : 0.30))
      .clamp(100.0, 300.0)
      .toDouble();
  var radialWidth = (width * (compact ? 0.28 : 0.26))
      .clamp(84.0, 240.0)
      .toDouble();
  final minMiddle = compact ? 120.0 : 210.0;
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
    compact: compact,
  );
}

class _SkillsListPane extends StatelessWidget {
  const _SkillsListPane({
    required this.selectedSlot,
    required this.candidates,
    required this.selectedAbilityId,
    required this.compact,
    required this.onSelectAbility,
    required this.onSelectProjectileSource,
  });

  final AbilitySlot selectedSlot;
  final List<AbilityPickerCandidate> candidates;
  final AbilityKey? selectedAbilityId;
  final bool compact;
  final ValueChanged<AbilityPickerCandidate> onSelectAbility;
  final VoidCallback? onSelectProjectileSource;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final panePadding = compact ? ui.space.xs : ui.space.sm;
    final titleStyle = compact
        ? ui.text.body.copyWith(
            color: ui.colors.textPrimary,
            fontWeight: FontWeight.w700,
          )
        : ui.text.headline.copyWith(color: ui.colors.textPrimary);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(panePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_slotTitle(selectedSlot)} Abilities',
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
          if (onSelectProjectileSource != null) ...[
            AppButton(
              label: 'Select Projectile Source',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.xs,
              onPressed: onSelectProjectileSource,
            ),
            SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final selected = candidate.id == selectedAbilityId;
                return _AbilityListTile(
                  title: abilityDisplayName(candidate.id),
                  selected: selected,
                  enabled: candidate.isEnabled,
                  compact: compact,
                  onTap: () => onSelectAbility(candidate),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsDetailsPane extends StatelessWidget {
  const _SkillsDetailsPane({
    required this.slot,
    required this.candidate,
    required this.tooltip,
  });

  final AbilitySlot slot;
  final AbilityPickerCandidate? candidate;
  final AbilityTooltip? tooltip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _AbilityDetailsPane(
        slot: slot,
        candidate: candidate,
        tooltip: tooltip,
      ),
    );
  }
}

class _SkillsRadialPane extends StatelessWidget {
  const _SkillsRadialPane({
    required this.characterId,
    required this.selectedSlot,
    required this.onSelectSlot,
    required this.compact,
  });

  final PlayerCharacterId characterId;
  final AbilitySlot selectedSlot;
  final ValueChanged<AbilitySlot> onSelectSlot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final panePadding = compact ? ui.space.xs : ui.space.sm;
    final titleStyle = compact
        ? ui.text.caption.copyWith(color: ui.colors.textPrimary)
        : ui.text.headline.copyWith(color: ui.colors.textPrimary);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(panePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Skill Wheel', style: titleStyle, textAlign: TextAlign.center),
          SizedBox(height: compact ? ui.space.xxs : ui.space.xs),
          Expanded(
            child: _ActionSlotRadialPanel(
              characterId: characterId,
              selectedSlot: selectedSlot,
              onSelectSlot: onSelectSlot,
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityListTile extends StatelessWidget {
  const _AbilityListTile({
    required this.title,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

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
              horizontal: compact ? ui.space.xs : ui.space.sm,
              vertical: compact ? ui.space.xxs : ui.space.xs,
            ),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: ui.text.body.copyWith(color: ui.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: ui.space.xs),
                AbilityPlaceholderIcon(
                  label: '',
                  size: compact ? 16 : 20,
                  emphasis: selected,
                  enabled: enabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectileSourceTile extends StatelessWidget {
  const _ProjectileSourceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final borderColor = selected
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(alpha: 0.45);
    final fillColor = selected
        ? const Color(0xFF1A1A1A)
        : const Color(0xFF131313);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ui.text.body.copyWith(color: ui.colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: ui.space.xxs),
              Text(
                subtitle,
                style: ui.text.caption.copyWith(color: ui.colors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbilityDetailsPane extends StatelessWidget {
  const _AbilityDetailsPane({
    required this.slot,
    required this.candidate,
    required this.tooltip,
  });

  final AbilitySlot slot;
  final AbilityPickerCandidate? candidate;
  final AbilityTooltip? tooltip;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(ui.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (candidate == null || tooltip == null) ...[
            Text(
              'No ability available for this slot.',
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
          ] else ...[
            Text(
              tooltip!.title,
              style: ui.text.headline.copyWith(color: ui.colors.textPrimary),
            ),
            SizedBox(height: ui.space.xxs),
            Text(
              tooltip!.subtitle,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
            if (tooltip!.badges.isNotEmpty) ...[
              SizedBox(height: ui.space.xs),
              Wrap(
                spacing: ui.space.xs,
                runSpacing: ui.space.xs,
                children: [
                  for (final badge in tooltip!.badges)
                    _AbilityBadge(text: badge),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AbilityBadge extends StatelessWidget {
  const _AbilityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui.space.xs,
        vertical: ui.space.xxs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: ui.text.caption.copyWith(color: ui.colors.textPrimary),
      ),
    );
  }
}

class _ActionSlotRadialPanel extends StatelessWidget {
  const _ActionSlotRadialPanel({
    required this.characterId,
    required this.selectedSlot,
    required this.onSelectSlot,
  });

  final PlayerCharacterId characterId;
  final AbilitySlot selectedSlot;
  final ValueChanged<AbilitySlot> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: _selectionActionSlotGeometry.width,
          height: _selectionActionSlotGeometry.height,
          child: Stack(
            children: [
              for (final slot in abilityRadialLayoutSpec.selectionOrder) ...[
                Positioned(
                  left:
                      _selectionActionSlotGeometry.placements[slot]!.buttonLeft,
                  top: _selectionActionSlotGeometry.placements[slot]!.buttonTop,
                  child: _ActionSlotButton(
                    slot: slot,
                    characterId: characterId,
                    selected: slot == selectedSlot,
                    onSelectSlot: onSelectSlot,
                    buttonSize: _selectionActionSlotGeometry
                        .placements[slot]!
                        .buttonSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSlotButton extends StatelessWidget {
  const _ActionSlotButton({
    required this.slot,
    required this.characterId,
    required this.selected,
    required this.onSelectSlot,
    required this.buttonSize,
  });

  final AbilitySlot slot;
  final PlayerCharacterId characterId;
  final bool selected;
  final ValueChanged<AbilitySlot> onSelectSlot;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final slotVisual = abilityRadialLayoutSpec.slotSpec(slot);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? ui.colors.accentStrong : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: ActionButton(
          label: slotVisual.label,
          icon: slotVisual.icon,
          onPressed: () => onSelectSlot(slot),
          tuning: _actionButtonTuningForSelectionSlot(
            tuning: _selectionControlsTuning,
            slot: slot,
          ),
          cooldownRing: _selectionControlsTuning.style.cooldownRing,
          size: buttonSize,
        ),
      ),
    );
  }
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

String _slotTitle(AbilitySlot slot) {
  switch (slot) {
    case AbilitySlot.primary:
      return 'Primary';
    case AbilitySlot.secondary:
      return 'Secondary';
    case AbilitySlot.projectile:
      return 'Projectile';
    case AbilitySlot.mobility:
      return 'Mobility';
    case AbilitySlot.spell:
      return 'Spell';
    case AbilitySlot.jump:
      return 'Jump';
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

@immutable
class _ActionSlotPlacement {
  const _ActionSlotPlacement({
    required this.buttonLeft,
    required this.buttonTop,
    required this.buttonSize,
  });

  final double buttonLeft;
  final double buttonTop;
  final double buttonSize;
}

@immutable
class _ActionSlotGeometry {
  const _ActionSlotGeometry({
    required this.width,
    required this.height,
    required this.placements,
  });

  final double width;
  final double height;
  final Map<AbilitySlot, _ActionSlotPlacement> placements;
}

const ControlsTuning _selectionControlsTuning = ControlsTuning.fixed;
final ControlsRadialLayout _selectionControlsRadialLayout =
    ControlsRadialLayoutSolver.solve(
      layout: _selectionControlsTuning.layout,
      action: _selectionControlsTuning.style.actionButton,
      directional: _selectionControlsTuning.style.directionalActionButton,
    );
final _ActionSlotGeometry _selectionActionSlotGeometry =
    _buildActionSlotsGeometry(layout: _selectionControlsRadialLayout);

_ActionSlotGeometry _buildActionSlotsGeometry({
  required ControlsRadialLayout layout,
}) {
  final rawSizes = <AbilitySlot, double>{
    for (final slot in abilityRadialLayoutSpec.selectionOrder)
      slot: abilityRadialLayoutSpec.sizeFor(layout: layout, slot: slot),
  };
  var baseWidth = 0.0;
  var baseHeight = 0.0;
  for (final slot in abilityRadialLayoutSpec.selectionOrder) {
    final size = rawSizes[slot]!;
    final anchor = abilityRadialLayoutSpec.anchorFor(
      layout: layout,
      slot: slot,
    );
    baseWidth = math.max(baseWidth, anchor.right + size);
    baseHeight = math.max(baseHeight, anchor.bottom + size);
  }

  final rawPlacements = <AbilitySlot, _ActionSlotPlacement>{};
  for (final slot in abilityRadialLayoutSpec.selectionOrder) {
    final size = rawSizes[slot]!;
    final anchor = abilityRadialLayoutSpec.anchorFor(
      layout: layout,
      slot: slot,
    );
    final buttonLeft = baseWidth - anchor.right - size;
    final buttonTop = baseHeight - anchor.bottom - size;
    rawPlacements[slot] = _ActionSlotPlacement(
      buttonLeft: buttonLeft,
      buttonTop: buttonTop,
      buttonSize: size,
    );
  }

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final placement in rawPlacements.values) {
    minX = math.min(minX, placement.buttonLeft);
    minY = math.min(minY, placement.buttonTop);
    maxX = math.max(maxX, placement.buttonLeft + placement.buttonSize);
    maxY = math.max(maxY, placement.buttonTop + placement.buttonSize);
  }
  final shiftX = minX < 0 ? -minX : 0.0;
  final shiftY = minY < 0 ? -minY : 0.0;

  final normalized = <AbilitySlot, _ActionSlotPlacement>{};
  for (final slot in abilityRadialLayoutSpec.selectionOrder) {
    final placement = rawPlacements[slot]!;
    normalized[slot] = _ActionSlotPlacement(
      buttonLeft: placement.buttonLeft + shiftX,
      buttonTop: placement.buttonTop + shiftY,
      buttonSize: placement.buttonSize,
    );
  }
  return _ActionSlotGeometry(
    width: maxX + shiftX,
    height: maxY + shiftY,
    placements: normalized,
  );
}

ActionButtonTuning _actionButtonTuningForSelectionSlot({
  required ControlsTuning tuning,
  required AbilitySlot slot,
}) {
  final family = abilityRadialLayoutSpec.slotSpec(slot).family;
  if (family == AbilityRadialSlotFamily.directional) {
    final directional = tuning.style.directionalActionButton;
    return _highContrastSelectionActionButtonTuning(
      ActionButtonTuning(
        size: directional.size,
        backgroundColor: directional.backgroundColor,
        foregroundColor: directional.foregroundColor,
        labelFontSize: directional.labelFontSize,
        labelGap: directional.labelGap,
      ),
    );
  }
  return _highContrastSelectionActionButtonTuning(tuning.style.actionButton);
}

ActionButtonTuning _highContrastSelectionActionButtonTuning(
  ActionButtonTuning base,
) {
  return ActionButtonTuning(
    size: base.size,
    backgroundColor: const Color(0xFFFFFFFF),
    foregroundColor: const Color(0xFF000000),
    labelFontSize: base.labelFontSize,
    labelGap: base.labelGap,
  );
}
