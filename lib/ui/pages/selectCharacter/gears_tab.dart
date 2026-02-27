import 'dart:math' as math;

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
  late final PageController _slotPageController;

  @override
  void initState() {
    super.initState();
    _slotPageController = PageController(
      initialPage: _indexForSlot(_selectedSlot),
    );
  }

  @override
  void dispose() {
    _slotPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final safePadding = MediaQuery.paddingOf(context);
    final appState = context.watch<AppState>();
    final meta = appState.meta;
    final equipped = meta.equippedFor(widget.characterId);
    final selectedSlotIndex = _indexForSlot(_selectedSlot);

    return Padding(
      padding: EdgeInsets.only(
        left: safePadding.left + ui.space.xs,
        right: safePadding.right,
      ),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 56,
                    child: _GearSlotSelector(
                      slotSpecs: _slotSpecs,
                      selectedSlot: _selectedSlot,
                      equipped: equipped,
                      onSelectSlot: (slot) => _onSelectSlot(
                        slot: slot,
                        equipped: equipped,
                        animatePage: true,
                      ),
                    ),
                  ),
                  _GearSlotSelectionDivider(
                    width: ui.space.md,
                    selectedIndex: selectedSlotIndex,
                    slotCount: _slotSpecs.length,
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ui.colors.cardBackground,
                        borderRadius: BorderRadius.circular(ui.radii.md),
                        border: Border.all(
                          color: ui.colors.outline.withValues(alpha: 0.4),
                        ),
                        boxShadow: ui.shadows.card,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(ui.space.sm),
                        child: PageView.builder(
                          controller: _slotPageController,
                          scrollDirection: Axis.vertical,
                          itemCount: _slotSpecs.length,
                          onPageChanged: (index) =>
                              _onPageChanged(index: index, equipped: equipped),
                          itemBuilder: (context, index) {
                            final slot = _slotSpecs[index].slot;
                            final candidates = _service
                                .candidatesForSlot(meta, slot)
                                .where((candidate) => candidate.isUnlocked)
                                .toList(growable: false);
                            final equippedId = _equippedIdForSlot(
                              slot,
                              equipped,
                            );
                            final selectedId = _selectedCandidateIdForSlot(
                              slot: slot,
                              candidates: candidates,
                              equippedId: equippedId,
                            );
                            final selectedCandidate = _candidateById(
                              candidates,
                              selectedId,
                            );
                            final canEquip =
                                selectedId != equippedId &&
                                selectedCandidate != null;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _GearDetailsPane(
                                    slot: slot,
                                    selectedId: selectedId,
                                    equippedForCompare: equippedId,
                                  ),
                                ),
                                SizedBox(width: ui.space.sm),
                                Expanded(
                                  flex: 1,
                                  child: _GearCandidatesPane(
                                    slot: slot,
                                    candidates: candidates,
                                    equippedId: equippedId,
                                    selectedId: selectedId,
                                    canEquip: canEquip,
                                    onSelected: (value) => setState(() {
                                      _selectedCandidateBySlot[slot] = value;
                                    }),
                                    onEquip: () => _equipSelected(
                                      appState: appState,
                                      slot: slot,
                                      selectedId: selectedId,
                                      equippedId: equippedId,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSelectSlot({
    required GearSlot slot,
    required EquippedGear equipped,
    required bool animatePage,
  }) {
    if (_selectedSlot == slot) return;
    setState(() {
      _selectedSlot = slot;
      _selectedCandidateBySlot.putIfAbsent(
        slot,
        () => _equippedIdForSlot(slot, equipped),
      );
    });
    if (!animatePage || !_slotPageController.hasClients) return;
    _slotPageController.animateToPage(
      _indexForSlot(slot),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged({required int index, required EquippedGear equipped}) {
    final slot = _slotSpecs[index].slot;
    if (_selectedSlot == slot) return;
    setState(() {
      _selectedSlot = slot;
      _selectedCandidateBySlot.putIfAbsent(
        slot,
        () => _equippedIdForSlot(slot, equipped),
      );
    });
  }

  int _indexForSlot(GearSlot slot) {
    for (var i = 0; i < _slotSpecs.length; i++) {
      if (_slotSpecs[i].slot == slot) return i;
    }
    return 0;
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
    for (final candidate in candidates) {
      if (candidate.id == equippedId) return equippedId;
    }
    return candidates.isNotEmpty ? candidates.first.id : equippedId;
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

class _GearSlotSelectionDivider extends StatelessWidget {
  const _GearSlotSelectionDivider({
    required this.width,
    required this.selectedIndex,
    required this.slotCount,
  });

  final double width;
  final int selectedIndex;
  final int slotCount;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    const markerHeight = 28.0;
    const slotSize = 48.0;
    final gap = ui.space.xs;

    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final laneHeight =
              ((slotCount * slotSize) + ((slotCount - 1).clamp(0, 9999) * gap))
                  .toDouble();
          final startY = ((maxHeight - laneHeight) / 2)
              .clamp(0.0, maxHeight)
              .toDouble();
          final targetY =
              startY +
              (selectedIndex * (slotSize + gap)) +
              ((slotSize - markerHeight) / 2);
          final clampedY = targetY
              .clamp(0.0, math.max(0.0, maxHeight - markerHeight))
              .toDouble();
          final markerWidth = (width * 0.35).clamp(3.0, 6.0).toDouble();

          return Stack(
            children: [
              Positioned.fill(
                child: VerticalDivider(
                  width: ui.space.xxs,
                  thickness: ui.sizes.borderWidth,
                  color: ui.colors.outline,
                  indent: ui.space.xxs,
                  endIndent: ui.space.xxs,
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: (width - markerWidth) / 2,
                top: clampedY,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ui.colors.accentStrong,
                      borderRadius: BorderRadius.circular(ui.radii.sm),
                    ),
                    child: SizedBox(width: markerWidth, height: markerHeight),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GearDetailsPane extends StatelessWidget {
  const _GearDetailsPane({
    required this.slot,
    required this.selectedId,
    required this.equippedForCompare,
  });

  final GearSlot slot;
  final Object selectedId;
  final Object equippedForCompare;

  @override
  Widget build(BuildContext context) {
    return GearPickerStatsPanel(
      slot: slot,
      id: selectedId,
      equippedForCompare: equippedForCompare,
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
          alignment: Alignment.center,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < slotSpecs.length; i++) ...[
          _GearSlotTab(
            slot: slotSpecs[i].slot,
            equippedId: _equippedIdForSlot(slotSpecs[i].slot, equipped),
            selected: slotSpecs[i].slot == selectedSlot,
            onTap: () => onSelectSlot(slotSpecs[i].slot),
          ),
          if (i < slotSpecs.length - 1) SizedBox(height: ui.space.xs),
        ],
      ],
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
    final selectedShadows = <BoxShadow>[
      ...ui.shadows.card,
      BoxShadow(
        color: ui.colors.accentStrong.withValues(alpha: 0.5),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ];

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
              boxShadow: selected ? selectedShadows : null,
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
