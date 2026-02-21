import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../core/abilities/ability_def.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/meta/meta_service.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/players/player_character_registry.dart';
import '../../components/gear_icon.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../controls/action_button.dart';
import '../../controls/ability_slot_visual_spec.dart';
import '../../controls/controls_tuning.dart';
import '../../controls/layout/controls_radial_layout.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'ability/ability_picker_dialog.dart';
import 'gear/gear_picker_dialog.dart';

// Keep multi-character backend logic intact; UI currently exposes only primary.
const List<PlayerCharacterDefinition> _loadoutSetupUiCharacters = [
  PlayerCharacterRegistry.eloise,
];

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
    final appState = context.read<AppState>();
    final selection = appState.selection;
    final defs = _loadoutSetupUiCharacters;
    _initialTabIndex = defs.indexWhere(
      (d) => d.id == selection.selectedCharacterId,
    );
    if (_initialTabIndex < 0) {
      _initialTabIndex = 0;
      unawaited(appState.setCharacter(defs.first.id));
    }
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final defs = _loadoutSetupUiCharacters;
    final appBarTitle = defs.length > 1
        ? TabBar(
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
          )
        : Text(
            defs.first.displayName,
            style: ui.text.label.copyWith(color: ui.colors.textPrimary),
          );

    return DefaultTabController(
      length: defs.length,
      initialIndex: _initialTabIndex,
      child: MenuScaffold(
        appBarTitle: appBarTitle,
        child: const MenuLayout(scrollable: false, child: _LoadoutSetupBody()),
      ),
    );
  }
}

class _LoadoutSetupBody extends StatelessWidget {
  const _LoadoutSetupBody();

  @override
  Widget build(BuildContext context) {
    final defs = _loadoutSetupUiCharacters;

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
    final gear = meta.equippedFor(characterId);
    const service = MetaService();

    return Padding(
      padding: EdgeInsets.only(left: ui.space.xxs, top: ui.space.xxs),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
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
                    child: GearIcon(
                      slot: GearSlot.spellBook,
                      id: gear.spellBookId,
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
                    child: GearIcon(
                      slot: GearSlot.accessory,
                      id: gear.accessoryId,
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
          Positioned.fill(
            child: _ActionSlotRadialPanel(characterId: characterId),
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

class _ActionSlotRadialPanel extends StatelessWidget {
  const _ActionSlotRadialPanel({required this.characterId});

  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.bottomRight,
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
    required this.buttonSize,
  });

  final AbilitySlot slot;
  final PlayerCharacterId characterId;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final slotVisual = abilityRadialLayoutSpec.slotSpec(slot);
    return ActionButton(
      label: slotVisual.label,
      icon: slotVisual.icon,
      onPressed: () => showAbilityPickerDialog(
        context,
        characterId: characterId,
        slot: slot,
      ),
      tuning: _actionButtonTuningForSelectionSlot(
        tuning: _selectionControlsTuning,
        slot: slot,
      ),
      cooldownRing: _selectionControlsTuning.style.cooldownRing,
      size: buttonSize,
    );
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
