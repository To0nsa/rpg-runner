import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/abilities/ability_catalog.dart';
import '../../../core/abilities/ability_def.dart';
import '../../../core/accessories/accessory_id.dart';
import '../../../core/players/character_ability_namespace.dart';
import '../../../core/players/player_character_definition.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../../core/spellBook/spell_book_id.dart';
import '../../../core/weapons/weapon_catalog.dart';
import '../../../core/weapons/weapon_category.dart';
import '../../../core/weapons/weapon_id.dart';
import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../components/gold_display.dart';
import '../../components/menu_layout.dart';
import '../../components/menu_scaffold.dart';
import '../../state/app_state.dart';
import '../../state/loadout_ownership_api.dart';
import '../../state/progression_state.dart';
import '../../theme/ui_tokens.dart';
import 'town_store_widgets.dart';

const int _dailyRefreshLimit = 3;
const int _goldRefreshCost = 50;
const WeaponCatalog _weaponCatalog = WeaponCatalog();

const List<StoreBucket> _bucketOrder = <StoreBucket>[
  StoreBucket.sword,
  StoreBucket.shield,
  StoreBucket.accessory,
  StoreBucket.spellBook,
  StoreBucket.projectileSpell,
  StoreBucket.spell,
  StoreBucket.ability,
];

const Map<StoreBucket, int> _bucketSortOrder = <StoreBucket, int>{
  StoreBucket.sword: 0,
  StoreBucket.shield: 1,
  StoreBucket.accessory: 2,
  StoreBucket.spellBook: 3,
  StoreBucket.projectileSpell: 4,
  StoreBucket.spell: 5,
  StoreBucket.ability: 6,
};

const List<AbilitySlot> _nonSpellAbilitySlots = <AbilitySlot>[
  AbilitySlot.primary,
  AbilitySlot.secondary,
  AbilitySlot.projectile,
  AbilitySlot.mobility,
  AbilitySlot.jump,
];

class TownPage extends StatefulWidget {
  const TownPage({super.key});

  @override
  State<TownPage> createState() => _TownPageState();
}

class _TownPageState extends State<TownPage> {
  bool _purchaseInFlight = false;
  bool _refreshInFlight = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final store = appState.progression.store;
    final activeOffers = _sortActiveOffers(store.activeOffers);
    final refreshesRemaining = math.max(
      0,
      _dailyRefreshLimit - store.refreshesUsedToday,
    );
    final canAnyOfferChange = _canAnyOfferChange(appState, store.activeOffers);
    final canRefreshForGold =
        !_purchaseInFlight &&
        !_refreshInFlight &&
        appState.progression.gold >= _goldRefreshCost &&
        refreshesRemaining > 0 &&
        canAnyOfferChange;

    return MenuScaffold(
      title: 'Town Store',
      child: MenuLayout(
        maxWidth: 1200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TownStoreCard(
              gold: appState.progression.gold,
              refreshesRemaining: refreshesRemaining,
              inFlight: _refreshInFlight,
              canRefresh: canRefreshForGold,
              onRefreshPressed: () => _confirmRefreshForGold(appState),
              activeOffers: activeOffers,
              currentGold: appState.progression.gold,
              purchaseInFlight: _purchaseInFlight,
              refreshInFlight: _refreshInFlight,
              onConfirmPurchase: (offer) => _confirmPurchase(appState, offer),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPurchase(
    AppState appState,
    StoreOfferState offer,
  ) async {
    if (_purchaseInFlight || _refreshInFlight) {
      return;
    }
    setState(() {
      _purchaseInFlight = true;
    });
    try {
      final result = await appState.purchaseStoreOffer(offerId: offer.offerId);
      if (!mounted) {
        return;
      }
      if (result.accepted) {
        _showSnackBar('Purchased ${townStoreOfferDisplayName(offer)}.');
      } else {
        _showSnackBar(_storeRejectedReasonText(result.rejectedReason));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Purchase failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _purchaseInFlight = false;
        });
      }
    }
  }

  Future<void> _confirmRefreshForGold(AppState appState) async {
    if (_purchaseInFlight || _refreshInFlight) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final ui = dialogContext.ui;
        return AppDialog(
          title: 'Refresh store?',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refreshing the store costs',
                style: ui.text.body.copyWith(color: ui.colors.textPrimary),
              ),
              SizedBox(height: ui.space.xs),
              const GoldDisplay(
                gold: _goldRefreshCost,
                label: 'Cost',
                variant: GoldDisplayVariant.body,
              ),
              SizedBox(height: ui.space.xs),
              Text(
                'Are you sure you want to refresh the store?',
                style: ui.text.body.copyWith(color: ui.colors.textPrimary),
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.xs,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton(
              label: 'Refresh',
              size: AppButtonSize.xs,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _refreshForGold(appState);
  }

  Future<void> _refreshForGold(AppState appState) async {
    if (_purchaseInFlight || _refreshInFlight) {
      return;
    }
    setState(() {
      _refreshInFlight = true;
    });
    try {
      final result = await appState.refreshStore(
        method: StoreRefreshMethod.gold,
      );
      if (!mounted) {
        return;
      }
      if (result.accepted) {
        _showSnackBar('Store refreshed.');
      } else {
        _showSnackBar(_storeRejectedReasonText(result.rejectedReason));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Refresh failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _refreshInFlight = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _storeRejectedReasonText(OwnershipRejectedReason? reason) {
  return switch (reason) {
    OwnershipRejectedReason.insufficientGold =>
      'Not enough gold for that action.',
    OwnershipRejectedReason.offerUnavailable =>
      'That offer is no longer available.',
    OwnershipRejectedReason.alreadyOwned => 'You already own this unlock.',
    OwnershipRejectedReason.refreshLimitReached =>
      'Daily refresh limit reached.',
    OwnershipRejectedReason.invalidRefreshMethod =>
      'Refresh method is not available.',
    OwnershipRejectedReason.nothingToRefresh =>
      'No offer can change right now.',
    OwnershipRejectedReason.rewardNotVerified =>
      'Reward verification is not active yet.',
    OwnershipRejectedReason.rewardAlreadyConsumed =>
      'Reward has already been used.',
    OwnershipRejectedReason.rewardExpired => 'Reward has expired.',
    _ => 'Action rejected. Please try again.',
  };
}

bool _canAnyOfferChange(AppState appState, List<StoreOfferState> activeOffers) {
  final characterId = appState.selection.selectedCharacterId;
  for (final offer in activeOffers) {
    final candidates = _candidatePoolForBucket(appState, offer.bucket);
    for (final candidate in candidates) {
      if (candidate.itemId == offer.itemId) {
        continue;
      }
      if (!_isCandidateOwned(
        appState: appState,
        candidate: candidate,
        characterId: characterId,
      )) {
        return true;
      }
    }
  }
  return false;
}

List<StoreOfferState> _sortActiveOffers(List<StoreOfferState> activeOffers) {
  final sorted = activeOffers.toList();
  sorted.sort((a, b) {
    final bucketRankA = _bucketSortOrder[a.bucket] ?? _bucketOrder.length;
    final bucketRankB = _bucketSortOrder[b.bucket] ?? _bucketOrder.length;
    final bucketOrderCompare = bucketRankA.compareTo(bucketRankB);
    if (bucketOrderCompare != 0) {
      return bucketOrderCompare;
    }
    return a.offerId.compareTo(b.offerId);
  });
  return sorted;
}

List<_StoreCandidateDefinition> _candidatePoolForBucket(
  AppState appState,
  StoreBucket bucket,
) {
  final out = <_StoreCandidateDefinition>[];
  switch (bucket) {
    case StoreBucket.sword:
      for (final id in WeaponId.values) {
        final def = _weaponCatalog.tryGet(id);
        if (def?.category != WeaponCategory.primary) {
          continue;
        }
        out.add(
          _StoreCandidateDefinition(
            domain: StoreDomain.gear,
            slot: StoreSlot.mainWeapon,
            itemId: id.name,
          ),
        );
      }
      return out;
    case StoreBucket.shield:
      for (final id in WeaponId.values) {
        final def = _weaponCatalog.tryGet(id);
        if (def?.category != WeaponCategory.offHand) {
          continue;
        }
        out.add(
          _StoreCandidateDefinition(
            domain: StoreDomain.gear,
            slot: StoreSlot.offhandWeapon,
            itemId: id.name,
          ),
        );
      }
      return out;
    case StoreBucket.accessory:
      for (final id in AccessoryId.values) {
        out.add(
          _StoreCandidateDefinition(
            domain: StoreDomain.gear,
            slot: StoreSlot.accessory,
            itemId: id.name,
          ),
        );
      }
      return out;
    case StoreBucket.spellBook:
      for (final id in SpellBookId.values) {
        out.add(
          _StoreCandidateDefinition(
            domain: StoreDomain.gear,
            slot: StoreSlot.spellBook,
            itemId: id.name,
          ),
        );
      }
      return out;
    case StoreBucket.projectileSpell:
      for (final id in ProjectileId.values) {
        if (id == ProjectileId.unknown) {
          continue;
        }
        out.add(
          _StoreCandidateDefinition(
            domain: StoreDomain.projectileSpell,
            slot: StoreSlot.projectile,
            itemId: id.name,
          ),
        );
      }
      return out;
    case StoreBucket.spell:
      for (final id in _abilityIdsForCharacterAndSlot(
        appState.selection.selectedCharacterId,
        AbilitySlot.spell,
      )) {
        out.add(
          _StoreCandidateDefinition(
            domain: StoreDomain.ability,
            slot: StoreSlot.spell,
            itemId: id,
          ),
        );
      }
      return out;
    case StoreBucket.ability:
      for (final slot in _nonSpellAbilitySlots) {
        final storeSlot = _storeSlotForAbilitySlot(slot);
        for (final id in _abilityIdsForCharacterAndSlot(
          appState.selection.selectedCharacterId,
          slot,
        )) {
          out.add(
            _StoreCandidateDefinition(
              domain: StoreDomain.ability,
              slot: storeSlot,
              itemId: id,
            ),
          );
        }
      }
      return out;
  }
}

Iterable<AbilityKey> _abilityIdsForCharacterAndSlot(
  PlayerCharacterId characterId,
  AbilitySlot slot,
) {
  final namespace = characterAbilityNamespace(characterId);
  final ids = <AbilityKey>[];
  for (final entry in AbilityCatalog.abilities.entries) {
    final id = entry.key;
    final def = entry.value;
    if (!id.startsWith('$namespace.')) {
      continue;
    }
    if (!def.allowedSlots.contains(slot)) {
      continue;
    }
    ids.add(id);
  }
  ids.sort();
  return ids;
}

bool _isCandidateOwned({
  required AppState appState,
  required _StoreCandidateDefinition candidate,
  required PlayerCharacterId characterId,
}) {
  final inventory = appState.meta.inventory;
  switch (candidate.domain) {
    case StoreDomain.gear:
      switch (candidate.slot) {
        case StoreSlot.mainWeapon:
        case StoreSlot.offhandWeapon:
          final id = _enumByName(WeaponId.values, candidate.itemId);
          return id != null && inventory.unlockedWeaponIds.contains(id);
        case StoreSlot.spellBook:
          final id = _enumByName(SpellBookId.values, candidate.itemId);
          return id != null && inventory.unlockedSpellBookIds.contains(id);
        case StoreSlot.accessory:
          final id = _enumByName(AccessoryId.values, candidate.itemId);
          return id != null && inventory.unlockedAccessoryIds.contains(id);
        default:
          return false;
      }
    case StoreDomain.projectileSpell:
      final ownership = appState.meta.abilityOwnershipFor(characterId);
      final id = _enumByName(ProjectileId.values, candidate.itemId);
      if (id == null) {
        return false;
      }
      return ownership.learnedProjectileSpellIds.contains(id);
    case StoreDomain.ability:
      final abilitySlot = _abilitySlotForStoreSlot(candidate.slot);
      if (abilitySlot == null) {
        return false;
      }
      final ownership = appState.meta.abilityOwnershipFor(characterId);
      return ownership
          .learnedAbilityIdsForSlot(abilitySlot)
          .contains(candidate.itemId);
  }
}

class _StoreCandidateDefinition {
  const _StoreCandidateDefinition({
    required this.domain,
    required this.slot,
    required this.itemId,
  });

  final StoreDomain domain;
  final StoreSlot slot;
  final String itemId;
}

AbilitySlot? _abilitySlotForStoreSlot(StoreSlot slot) {
  return switch (slot) {
    StoreSlot.primary => AbilitySlot.primary,
    StoreSlot.secondary => AbilitySlot.secondary,
    StoreSlot.projectile => AbilitySlot.projectile,
    StoreSlot.mobility => AbilitySlot.mobility,
    StoreSlot.jump => AbilitySlot.jump,
    StoreSlot.spell => AbilitySlot.spell,
    _ => null,
  };
}

StoreSlot _storeSlotForAbilitySlot(AbilitySlot slot) {
  return switch (slot) {
    AbilitySlot.primary => StoreSlot.primary,
    AbilitySlot.secondary => StoreSlot.secondary,
    AbilitySlot.projectile => StoreSlot.projectile,
    AbilitySlot.mobility => StoreSlot.mobility,
    AbilitySlot.jump => StoreSlot.jump,
    AbilitySlot.spell => StoreSlot.spell,
  };
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}
