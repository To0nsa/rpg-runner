import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/meta/equipped_gear.dart';
import '../../../../core/meta/gear_slot.dart';
import '../../../../core/meta/meta_service.dart';
import '../../../../core/meta/meta_state.dart';
import '../../../../core/players/player_character_definition.dart';
import '../../../components/app_button.dart';
import '../../../state/app_state.dart';
import '../../../theme/ui_tokens.dart';
import 'gear_picker_candidates_panel.dart';
import 'gear_picker_stats_panel.dart';

/// Opens the gear picker modal for a specific [slot] and [characterId].
///
/// The dialog itself is a lightweight shell; panel rendering and stat
/// computation are delegated to dedicated modules.
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

/// Shell widget that owns dialog-local state and action wiring.
///
/// Responsibilities kept here:
/// - modal sizing/layout
/// - selected candidate state
/// - equip action dispatch through [AppState]
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
    final candidates = widget.service.candidatesForSlot(
      widget.meta,
      widget.slot,
    );
    final selectedId = _selectedCandidate;

    // Resolve selected candidate metadata once so "Equip" can be disabled for
    // locked entries even if they are highlighted.
    GearSlotCandidate? selectedCandidate;
    if (selectedId != null) {
      for (final candidate in candidates) {
        if (candidate.id == selectedId) {
          selectedCandidate = candidate;
          break;
        }
      }
    }
    final canSwap =
        selectedId != null &&
        selectedId != equippedId &&
        (selectedCandidate?.isUnlocked ?? false);

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
      backgroundColor: ui.colors.cardBackground,
      insetPadding: EdgeInsets.all(inset),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.md),
        side: BorderSide(
          color: ui.colors.outline.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
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
                      child: GearPickerStatsPanel(
                        slot: widget.slot,
                        id: selectedId,
                        equippedForCompare: equippedId,
                      ),
                    ),
                    SizedBox(width: paneSpacing),
                    Expanded(
                      child: GearPickerCandidatesPanel(
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

/// Compact action row shared by all slot pickers.
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

/// Reads equipped item id for [slot] from [equipped].
Object _equippedIdForSlot(GearSlot slot, EquippedGear equipped) {
  return switch (slot) {
    GearSlot.mainWeapon => equipped.mainWeaponId,
    GearSlot.offhandWeapon => equipped.offhandWeaponId,
    GearSlot.throwingWeapon => equipped.throwingWeaponId,
    GearSlot.spellBook => equipped.spellBookId,
    GearSlot.accessory => equipped.accessoryId,
  };
}
