import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';

import '../../components/gold_display.dart';
import '../../components/menu_scaffold.dart';
import '../../l10n/app_localization.dart';
import '../../state/app/app_state.dart';
import '../../state/ownership/loadout_ownership_api.dart';
import '../../state/ownership/progression_state.dart';
import '../../text/build_name_text.dart';
import '../../theme/ui_tokens.dart';
import 'town_catalog.dart';
import 'town_store_widgets.dart';
import 'reward_verification_dialog.dart';

/// The two town entrances share a catalogue UI, with browsing local to this route.
class TownStorePage extends StatefulWidget {
  const TownStorePage({super.key, this.initialService = TownService.equipment});
  final TownService initialService;

  @override
  State<TownStorePage> createState() => _TownStorePageState();
}

class _TownStorePageState extends State<TownStorePage> {
  bool _purchaseInFlight = false;
  late TownService _service;
  late PlayerCharacterId _characterId;
  StoreSlot? _slot;
  String? _expandedOfferId;
  bool _hideOwned = false;

  @override
  void initState() {
    super.initState();
    _service = widget.initialService;
    final active = context.read<AppState>().selection.selectedCharacterId;
    _characterId = PlayerCharacterRegistry.playable.any((c) => c.id == active)
        ? active
        : PlayerCharacterId.eloise;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ui = context.ui;
    final l10n = context.l10n;
    final loadout = app.selection.loadoutFor(_characterId);
    final offers = app.progression.store.catalogOffers
        .where(
          (offer) =>
              offer.characterIds.contains(_characterId) &&
              _service.includes(offer) &&
              (_slot == null || offer.slot == _slot) &&
              (!_hideOwned || !townOfferOwned(app.meta, _characterId, offer)),
        )
        .toList();
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
    return MenuScaffold(
      title: _service.label(l10n),
      appBarActions: [
        Padding(
          padding: EdgeInsets.only(right: ui.space.md),
          child: GoldDisplay(gold: app.displayedGold),
        ),
      ],
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView.builder(
            key: ValueKey(
              'catalogue-${_service.name}-${_characterId.name}-${_slot?.name}',
            ),
            padding: EdgeInsets.all(ui.space.md),
            itemCount: offers.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: ui.space.sm,
                      runSpacing: ui.space.xs,
                      children: [
                        for (final service in TownService.values)
                          ChoiceChip(
                            key: ValueKey('service-${service.name}'),
                            label: Text(service.label(l10n)),
                            selected: _service == service,
                            onSelected: _purchaseInFlight
                                ? null
                                : (_) => setState(() {
                                    _service = service;
                                    _slot = null;
                                    _expandedOfferId = null;
                                  }),
                          ),
                      ],
                    ),
                    SizedBox(height: ui.space.sm),
                    Text(
                      _service == TownService.equipment
                          ? l10n.townEquipmentIntro
                          : l10n.townTrainingIntro,
                      style: ui.text.body.copyWith(color: ui.colors.textMuted),
                    ),
                    SizedBox(height: ui.space.sm),
                    Wrap(
                      spacing: ui.space.sm,
                      runSpacing: ui.space.xs,
                      children: [
                        for (final character
                            in PlayerCharacterRegistry.playable)
                          ChoiceChip(
                            key: ValueKey(
                              'catalogue-character-${character.id.name}',
                            ),
                            label: Text(
                              characterDisplayName(
                                character.id,
                                strings: context.gameL10n,
                              ),
                            ),
                            selected: _characterId == character.id,
                            onSelected: _purchaseInFlight
                                ? null
                                : (_) => setState(() {
                                    _characterId = character.id;
                                    _expandedOfferId = null;
                                  }),
                          ),
                      ],
                    ),
                    SizedBox(height: ui.space.xs),
                    Wrap(
                      spacing: ui.space.xs,
                      runSpacing: ui.space.xxs,
                      children: [
                        for (final slot in <StoreSlot?>[
                          null,
                          ..._service.slots,
                        ])
                          ChoiceChip(
                            key: ValueKey(
                              'catalogue-slot-${slot?.name ?? 'all'}',
                            ),
                            label: Text(
                              slot == null
                                  ? l10n.townAllCategories
                                  : l10n.townCategory(
                                      character: _characterId.name,
                                      service: _service.name,
                                      slot: slot.name,
                                    ),
                            ),
                            selected: _slot == slot,
                            onSelected: (_) => setState(() {
                              _slot = slot;
                              _expandedOfferId = null;
                            }),
                          ),
                        FilterChip(
                          label: Text(l10n.townUnownedOnly),
                          selected: _hideOwned,
                          onSelected: (value) =>
                              setState(() => _hideOwned = value),
                        ),
                      ],
                    ),
                    SizedBox(height: ui.space.sm),
                    if (offers.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(ui.space.md),
                        child: Text(
                          app.progression.store.schemaVersion < 2
                              ? l10n.townCatalogueUnavailable
                              : l10n.townNoMatchingEntries,
                          style: ui.text.body,
                        ),
                      ),
                  ],
                );
              }
              final offer = offers[index - 1];
              return Padding(
                padding: EdgeInsets.only(bottom: ui.space.sm),
                child: TownOfferCard(
                  key: ValueKey('offer-${offer.offerId}'),
                  offer: offer,
                  owned: townOfferOwned(app.meta, _characterId, offer),
                  expanded: _expandedOfferId == offer.offerId,
                  currentGold: app.displayedGold,
                  purchaseInFlight: _purchaseInFlight,
                  selectedLoadout: loadout,
                  buildName: buildDisplayName(
                    app.selection.buildsFor(_characterId).selected.name,
                    app.selection.selectedBuildIndexFor(_characterId),
                    l10n,
                  ),
                  characterId: _characterId,
                  onToggleExpanded: () => setState(
                    () => _expandedOfferId = _expandedOfferId == offer.offerId
                        ? null
                        : offer.offerId,
                  ),
                  onConfirmPurchase: (offer) =>
                      _confirmPurchase(app, offer, _characterId),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPurchase(
    AppState appState,
    StoreOfferState offer,
    PlayerCharacterId characterId,
  ) async {
    if (_purchaseInFlight) {
      return;
    }
    if (appState.goldNeedsVerification(offer.priceGold)) {
      await _showRewardVerification(appState, offer.priceGold);
      return;
    }
    setState(() {
      _purchaseInFlight = true;
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
