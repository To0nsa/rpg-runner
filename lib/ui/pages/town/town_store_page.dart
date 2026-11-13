import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../../components/gold_display.dart';
import '../../components/app_segmented_control.dart';
import '../../components/menu_scaffold.dart';
import '../../l10n/app_localization.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/loadout_ownership_api.dart';
import '../../state/ownership/progression_state.dart';
import '../../theme/ui_tokens.dart';
import 'town_catalog.dart';
import 'town_equipment_args.dart';
import 'town_store_workspace.dart';
import 'town_store_widgets.dart';
import 'reward_verification_dialog.dart';

/// Town entrances own separate services; browsing never changes run selection.
class TownStorePage extends StatefulWidget {
  const TownStorePage({
    super.key,
    this.initialService = TownService.equipment,
    this.equipmentArgs,
  });
  final TownService initialService;
  final TownEquipmentArgs? equipmentArgs;

  @override
  State<TownStorePage> createState() => _TownStorePageState();
}

class _TownStorePageState extends State<TownStorePage> {
  bool _purchaseInFlight = false;
  late PlayerCharacterId _characterId;
  StoreSlot? _slot;
  int? _equipmentBuildIndex;
  String? _selectedOfferId;

  TownService get _service => widget.initialService;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final args = _service == TownService.equipment
        ? widget.equipmentArgs
        : null;
    final active = args?.characterId ?? app.selection.selectedCharacterId;
    _characterId =
        PlayerCharacterRegistry.playable.any(
          (c) => c.id == active && app.isCharacterUnlocked(c.id),
        )
        ? active
        : PlayerCharacterId.eloise;
    final buildIndex = args?.buildIndex;
    if (args?.characterId == _characterId &&
        buildIndex != null &&
        app.isBuildUnlocked(buildIndex)) {
      _equipmentBuildIndex = buildIndex;
    }
    if (_service == TownService.equipment) {
      final available = app.progression.store.catalogOffers.where(
        (offer) =>
            offer.characterIds.contains(_characterId) &&
            _service.includes(offer),
      );
      _slot = args != null && _service.slots.contains(args.slot)
          ? args.slot
          : _service.slots.firstWhere(
              (slot) => available.any(
                (offer) =>
                    offer.slot == slot &&
                    !townOfferOwned(app.meta, _characterId, offer),
              ),
              orElse: () => _service.slots.first,
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // A refreshed account can revoke availability while this route stays open.
    final characterId = app.isCharacterUnlocked(_characterId)
        ? _characterId
        : PlayerCharacterId.eloise;
    final ui = context.ui;
    final l10n = context.l10n;
    final equipment = _service == TownService.equipment;
    final inlineCharacter =
        MediaQuery.sizeOf(context).width /
            MediaQuery.textScalerOf(context).scale(1) >=
        560;
    final buildIndex =
        (_characterId == characterId ? _equipmentBuildIndex : null) ??
        app.selection.selectedBuildIndexFor(characterId);
    final loadout = app.selection.loadoutFor(
      characterId,
      buildIndex: buildIndex,
    );
    final offers = (app.progression.store.schemaVersion < 2
        ? <StoreOfferState>[]
        : app.progression.store.catalogOffers
              .where(
                (offer) =>
                    offer.characterIds.contains(characterId) &&
                    _service.includes(offer) &&
                    (_slot == null || offer.slot == _slot) &&
                    (!equipment ||
                        !townOfferOwned(app.meta, characterId, offer)),
              )
              .toList());
    offers.sort((a, b) {
      final slot = _service.slots
          .indexOf(a.slot)
          .compareTo(_service.slots.indexOf(b.slot));
      return slot != 0
          ? slot
          : townStoreOfferDisplayName(a, strings: context.gameL10n).compareTo(
              townStoreOfferDisplayName(b, strings: context.gameL10n),
            );
    });
    StoreOfferState? selected;
    for (final offer in offers) {
      if (offer.offerId == _selectedOfferId) selected = offer;
    }
    selected ??= offers.firstOrNull;
    final emptyText = app.progression.store.schemaVersion < 2
        ? l10n.townCatalogueUnavailable
        : l10n.townNoMatchingEntries;
    return MenuScaffold(
      appBarTitle: Row(
        children: [
          SizedBox(width: ui.space.sm),
          Expanded(
            child: Text(
              _service.label(l10n),
              style: ui.text.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (inlineCharacter) _characterPicker(characterId, app),
        ],
      ),
      appBarActions: [
        Padding(
          padding: EdgeInsets.only(left: ui.space.sm, right: ui.space.md),
          child: GoldDisplay(gold: app.displayedGold),
        ),
      ],
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: EdgeInsets.all(ui.space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!inlineCharacter)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _characterPicker(characterId, app),
                  ),
                Expanded(
                  child: TownStoreWorkspace(
                    service: _service,
                    characterId: characterId,
                    slot: _slot,
                    offers: offers,
                    selectedOffer: selected,
                    selectedLoadout: loadout,
                    emptyText: emptyText,
                    currentGold: app.displayedGold,
                    purchaseInFlight: _purchaseInFlight,
                    ownedOfferIds: {
                      for (final offer in offers)
                        if (townOfferOwned(app.meta, characterId, offer))
                          offer.offerId,
                    },
                    onSelectSlot: (slot) => setState(() {
                      _slot = slot;
                      _selectedOfferId = null;
                    }),
                    onSelectOffer: (offer) => setState(() {
                      _selectedOfferId = offer.offerId;
                    }),
                    onPurchase: (offer) =>
                        _confirmPurchase(app, offer, characterId),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _characterPicker(PlayerCharacterId selected, AppState app) {
    return Semantics(
      label: context.l10n.uiCharacter,
      child: AppSegmentedControl<PlayerCharacterId>(
        key: const ValueKey('catalogue-character-picker'),
        values: [
          for (final character in PlayerCharacterRegistry.playable)
            character.id,
        ],
        selected: selected,
        enabled: !_purchaseInFlight,
        isValueEnabled: app.isCharacterUnlocked,
        size: AppSegmentedControlSize.sm,
        onChanged: (id) {
          if (_purchaseInFlight ||
              id == selected ||
              !context.read<AppState>().isCharacterUnlocked(id)) {
            return;
          }
          setState(() {
            _characterId = id;
            _equipmentBuildIndex = null;
            _selectedOfferId = null;
          });
        },
        labelBuilder: (context, id) {
          final name = characterDisplayName(id, strings: context.gameL10n);
          final unlocked = app.isCharacterUnlocked(id);
          final label = Row(
            key: ValueKey('catalogue-character-${id.name}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!unlocked) ...[
                const Icon(Icons.lock_outline, size: 14),
                SizedBox(width: context.ui.space.xxs),
              ],
              Flexible(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          );
          return unlocked
              ? label
              : Tooltip(
                  message: context.l10n.campaignWillowLocked,
                  child: label,
                );
        },
      ),
    );
  }

  Future<void> _confirmPurchase(
    AppState appState,
    StoreOfferState offer,
    PlayerCharacterId characterId,
  ) async {
    if (_purchaseInFlight || !appState.isCharacterUnlocked(characterId)) {
      return;
    }
    if (appState.goldNeedsVerification(offer.priceGold)) {
      await _showRewardVerification(appState, offer.priceGold);
      return;
    }
    setState(() {
      _purchaseInFlight = true;
      _selectedOfferId = offer.offerId;
    });
    try {
      final result = await appState.purchaseStoreOffer(
        offerId: offer.offerId,
        characterId: characterId,
      );
      if (!mounted) {
        return;
      }
      if (result.accepted) {
        _showSnackBar(
          context.l10n.storePurchaseComplete(
            item: townStoreOfferDisplayName(offer, strings: context.gameL10n),
          ),
        );
      } else if (result.rejectedReason ==
              OwnershipRejectedReason.insufficientGold &&
          appState.goldNeedsVerification(offer.priceGold)) {
        await _showRewardVerification(appState, offer.priceGold);
      } else {
        _showSnackBar(
          _storeRejectedReasonText(result.rejectedReason, context.l10n),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.l10n.uiPurchaseFailedPleaseTryAgain);
    } finally {
      if (mounted) {
        setState(() {
          _purchaseInFlight = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRewardVerification(AppState appState, int cost) =>
      showDialog<void>(
        context: context,
        builder: (_) =>
            RewardVerificationDialog(appState: appState, cost: cost),
      );
}

String _storeRejectedReasonText(
  OwnershipRejectedReason? reason,
  AppLocalizations l10n,
) {
  return switch (reason) {
    OwnershipRejectedReason.insufficientGold =>
      l10n.uiNotEnoughGoldForThatAction,
    OwnershipRejectedReason.offerUnavailable =>
      l10n.uiThatOfferIsNoLongerAvailable,
    OwnershipRejectedReason.alreadyOwned => l10n.uiYouAlreadyOwnThisUnlock,
    OwnershipRejectedReason.refreshLimitReached =>
      l10n.uiDailyRefreshLimitReached,
    OwnershipRejectedReason.invalidRefreshMethod =>
      l10n.uiRefreshMethodIsNotAvailable,
    OwnershipRejectedReason.nothingToRefresh => l10n.uiNoOfferCanChangeRightNow,
    OwnershipRejectedReason.rewardNotVerified =>
      l10n.uiRewardVerificationIsNotActiveYet,
    OwnershipRejectedReason.rewardAlreadyConsumed =>
      l10n.uiRewardHasAlreadyBeenUsed,
    OwnershipRejectedReason.rewardExpired => l10n.uiRewardHasExpired,
    _ => l10n.uiActionRejectedPleaseTryAgain,
  };
}
