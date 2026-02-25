import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/meta/equipped_gear.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/meta/meta_service.dart';
import '../../../core/players/player_character_definition.dart';
import '../../components/app_button.dart';
import '../../components/gear_icon.dart';
import '../../state/app_state.dart';
import '../../theme/ui_tokens.dart';
import 'gear/gear_picker_candidates_panel.dart';
import 'gear/gear_picker_stats_panel.dart';

/// In-tab gear management surface (no modal dialog).
///
/// Layout:
/// - left: slot selector + selected-item details
/// - right: selectable candidates for the active slot
class GearsTab extends StatefulWidget {
  const GearsTab({super.key, required this.characterId});

  final PlayerCharacterId characterId;

  @override
  State<GearsTab> createState() => _GearsTabState();
}

class _GearsTabState extends State<GearsTab> {
  static const List<_GearSlotSpec> _slotSpecs = <_GearSlotSpec>[
    _GearSlotSpec(slot: GearSlot.mainWeapon),
    _GearSlotSpec(slot: GearSlot.offhandWeapon),
    _GearSlotSpec(slot: GearSlot.throwingWeapon),
    _GearSlotSpec(slot: GearSlot.spellBook),
    _GearSlotSpec(slot: GearSlot.accessory),
  ];
  static const MetaService _service = MetaService();

  GearSlot _selectedSlot = GearSlot.mainWeapon;
  final Map<GearSlot, Object> _selectedCandidateBySlot = <GearSlot, Object>{};

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final appState = context.watch<AppState>();
    final meta = appState.meta;
    final equipped = meta.equippedFor(widget.characterId);

    final candidates = _service.candidatesForSlot(meta, _selectedSlot);
    final equippedId = _equippedIdForSlot(_selectedSlot, equipped);
    final selectedId = _selectedCandidateIdForSlot(
      slot: _selectedSlot,
      candidates: candidates,
      equippedId: equippedId,
    );
    final selectedCandidate = _candidateById(candidates, selectedId);
    final canEquip =
        selectedId != equippedId && (selectedCandidate?.isUnlocked ?? false);

    return Padding(
      padding: EdgeInsets.only(left: ui.space.xxs, top: ui.space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: _GearDetailsPane(
                    slotSpecs: _slotSpecs,
                    selectedSlot: _selectedSlot,
                    equipped: equipped,
                    selectedId: selectedId,
                    onSelectSlot: (slot) {
                      if (_selectedSlot == slot) return;
                      setState(() {
                        _selectedSlot = slot;
                        _selectedCandidateBySlot.putIfAbsent(
                          slot,
                          () => _equippedIdForSlot(slot, equipped),
                        );
                      });
                    },
                  ),
                ),
                SizedBox(width: ui.space.sm),
                Expanded(
                  flex: 1,
                  child: _GearCandidatesPane(
                    slot: _selectedSlot,
                    candidates: candidates,
                    equippedId: equippedId,
                    selectedId: selectedId,
                    canEquip: canEquip,
                    onSelected: (value) => setState(() {
                      _selectedCandidateBySlot[_selectedSlot] = value;
                    }),
                    onEquip: () => _equipSelected(
                      appState: appState,
                      slot: _selectedSlot,
                      selectedId: selectedId,
                      equippedId: equippedId,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Object _selectedCandidateIdForSlot({
    required GearSlot slot,
    required List<GearSlotCandidate> candidates,
    required Object equippedId,
  }) {
    final selected = _selectedCandidateBySlot[slot];
    if (selected != null) {
      for (final candidate in candidates) {
        if (candidate.id == selected) return selected;
      }
    }
    return equippedId;
  }

  Future<void> _equipSelected({
    required AppState appState,
    required GearSlot slot,
    required Object selectedId,
    required Object equippedId,
  }) async {
    if (selectedId == equippedId) return;
    await appState.equipGear(
      characterId: widget.characterId,
      slot: slot,
      itemId: selectedId,
    );
  }
}

class _GearDetailsPane extends StatelessWidget {
  const _GearDetailsPane({
    required this.slotSpecs,
    required this.selectedSlot,
    required this.equipped,
    required this.selectedId,
    required this.onSelectSlot,
  });

  final List<_GearSlotSpec> slotSpecs;
  final GearSlot selectedSlot;
  final EquippedGear equipped;
  final Object selectedId;
  final ValueChanged<GearSlot> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final equippedForCompare = _equippedIdForSlot(selectedSlot, equipped);
    const slotListWidth = 48.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: slotListWidth,
          child: _GearSlotSelector(
            slotSpecs: slotSpecs,
            selectedSlot: selectedSlot,
            equipped: equipped,
            onSelectSlot: onSelectSlot,
          ),
        ),
        SizedBox(width: ui.space.sm),
        Expanded(
          child: GearPickerStatsPanel(
            slot: selectedSlot,
            id: selectedId,
            equippedForCompare: equippedForCompare,
          ),
        ),
      ],
    );
  }
}

class _GearCandidatesPane extends StatelessWidget {
  const _GearCandidatesPane({
    required this.slot,
    required this.candidates,
    required this.equippedId,
    required this.selectedId,
    required this.canEquip,
    required this.onSelected,
    required this.onEquip,
  });

  final GearSlot slot;
  final List<GearSlotCandidate> candidates;
  final Object equippedId;
  final Object selectedId;
  final bool canEquip;
  final ValueChanged<Object> onSelected;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GearPickerCandidatesPanel(
            slot: slot,
            candidates: candidates,
            equippedId: equippedId,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
        ),
        SizedBox(height: ui.space.sm),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: 'Equip',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.xs,
            onPressed: canEquip ? onEquip : null,
          ),
        ),
      ],
    );
  }
}

class _GearSlotSelector extends StatelessWidget {
  const _GearSlotSelector({
    required this.slotSpecs,
    required this.selectedSlot,
    required this.equipped,
    required this.onSelectSlot,
  });

  final List<_GearSlotSpec> slotSpecs;
  final GearSlot selectedSlot;
  final EquippedGear equipped;
  final ValueChanged<GearSlot> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ListView.separated(
      itemCount: slotSpecs.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final spec = slotSpecs[index];
        return _GearSlotTab(
          slot: spec.slot,
          equippedId: _equippedIdForSlot(spec.slot, equipped),
          selected: spec.slot == selectedSlot,
          onTap: () => onSelectSlot(spec.slot),
        );
      },
      separatorBuilder: (_, _) => SizedBox(height: ui.space.xs),
    );
  }
}

class _GearSlotTab extends StatelessWidget {
  const _GearSlotTab({
    required this.slot,
    required this.equippedId,
    required this.selected,
    required this.onTap,
  });

  final GearSlot slot;
  final Object equippedId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final fillColor = selected
        ? UiBrandPalette.steelBlueInsetBottom
        : ui.colors.cardBackground;
    final borderColor = selected ? ui.colors.accentStrong : ui.colors.outline;

    return SizedBox.square(
      dimension: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui.radii.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              border: Border.all(color: borderColor),
              boxShadow: selected ? ui.shadows.card : null,
            ),
            alignment: Alignment.center,
            child: GearIcon(slot: slot, id: equippedId),
          ),
        ),
      ),
    );
  }
}

class _GearSlotSpec {
  const _GearSlotSpec({required this.slot});

  final GearSlot slot;
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

GearSlotCandidate? _candidateById(
  List<GearSlotCandidate> candidates,
  Object id,
) {
  for (final candidate in candidates) {
    if (candidate.id == id) return candidate;
  }
  return null;
}
