import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_state.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'progression_state.dart';
import 'selection_state.dart';

const String defaultOwnershipProfileId = 'main';

/// Canonical ownership state returned by the ownership API.
class OwnershipCanonicalState {
  const OwnershipCanonicalState({
    required this.profileId,
    required this.revision,
    required this.selection,
    required this.meta,
    required this.progression,
  });

  final String profileId;
  final int revision;
  final SelectionState selection;
  final MetaState meta;
  final ProgressionState progression;

  OwnershipCanonicalState copyWith({
    String? profileId,
    int? revision,
    SelectionState? selection,
    MetaState? meta,
    ProgressionState? progression,
  }) {
    return OwnershipCanonicalState(
      profileId: profileId ?? this.profileId,
      revision: revision ?? this.revision,
      selection: selection ?? this.selection,
      meta: meta ?? this.meta,
      progression: progression ?? this.progression,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'profileId': profileId,
      'revision': revision,
      'selection': selection.toJson(),
      'meta': meta.toJson(),
      'progression': progression.toJson(),
    };
  }

  static OwnershipCanonicalState fromJson(
    Map<String, dynamic> json, {
    required OwnershipCanonicalState fallback,
  }) {
    final profileIdRaw = json['profileId'];
    final revisionRaw = json['revision'];
    final selectionRaw = json['selection'];
    final metaRaw = json['meta'];
    final progressionRaw = json['progression'];
    final profileId = profileIdRaw is String && profileIdRaw.isNotEmpty
        ? profileIdRaw
        : fallback.profileId;
    final revision = revisionRaw is int
        ? revisionRaw
        : (revisionRaw is num ? revisionRaw.toInt() : fallback.revision);
    final selection = selectionRaw is Map<String, dynamic>
        ? SelectionState.fromJson(selectionRaw)
        : (selectionRaw is Map
              ? SelectionState.fromJson(Map<String, dynamic>.from(selectionRaw))
              : fallback.selection);
    final meta = metaRaw is Map<String, dynamic>
        ? MetaState.fromJson(metaRaw, fallback: fallback.meta)
        : (metaRaw is Map
              ? MetaState.fromJson(
                  Map<String, dynamic>.from(metaRaw),
                  fallback: fallback.meta,
                )
              : fallback.meta);
    final progression = progressionRaw is Map<String, dynamic>
        ? ProgressionState.fromJson(progressionRaw)
        : (progressionRaw is Map
              ? ProgressionState.fromJson(
                  Map<String, dynamic>.from(progressionRaw),
                )
              : fallback.progression);
    return OwnershipCanonicalState(
      profileId: profileId,
      revision: revision,
      selection: selection,
      meta: meta,
      progression: progression,
    );
  }
}

/// Reject reasons shared across ownership commands.
enum OwnershipRejectedReason {
  staleRevision,
  idempotencyKeyReuseMismatch,
  invalidCommand,
  forbidden,
  unauthorized,
  insufficientGold,
  offerUnavailable,
  alreadyOwned,
  refreshLimitReached,
  invalidRefreshMethod,
  rewardNotVerified,
  rewardAlreadyConsumed,
  rewardExpired,
  nothingToRefresh,
}

/// Unified command result envelope for ownership API mutations.
class OwnershipCommandResult {
  const OwnershipCommandResult({
    required this.canonicalState,
    required this.newRevision,
    required this.replayedFromIdempotency,
    this.rejectedReason,
  });

  final OwnershipCanonicalState canonicalState;
  final int newRevision;
  final bool replayedFromIdempotency;
  final OwnershipRejectedReason? rejectedReason;

  bool get accepted => rejectedReason == null;

  OwnershipCommandResult copyWith({
    OwnershipCanonicalState? canonicalState,
    int? newRevision,
    bool? replayedFromIdempotency,
    OwnershipRejectedReason? rejectedReason,
    bool overwriteRejectedReason = false,
  }) {
    return OwnershipCommandResult(
      canonicalState: canonicalState ?? this.canonicalState,
      newRevision: newRevision ?? this.newRevision,
      replayedFromIdempotency:
          replayedFromIdempotency ?? this.replayedFromIdempotency,
      rejectedReason: overwriteRejectedReason
          ? rejectedReason
          : (rejectedReason ?? this.rejectedReason),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'canonicalState': canonicalState.toJson(),
      'newRevision': newRevision,
      'replayedFromIdempotency': replayedFromIdempotency,
      'rejectedReason': rejectedReason?.name,
    };
  }

  static OwnershipCommandResult fromJson(
    Map<String, dynamic> json, {
    required OwnershipCanonicalState fallbackCanonicalState,
  }) {
    final canonicalRaw = json['canonicalState'];
    final newRevisionRaw = json['newRevision'];
    final replayedRaw = json['replayedFromIdempotency'];
    final reasonRaw = json['rejectedReason'];
    final canonicalState = canonicalRaw is Map<String, dynamic>
        ? OwnershipCanonicalState.fromJson(
            canonicalRaw,
            fallback: fallbackCanonicalState,
          )
        : (canonicalRaw is Map
              ? OwnershipCanonicalState.fromJson(
                  Map<String, dynamic>.from(canonicalRaw),
                  fallback: fallbackCanonicalState,
                )
              : fallbackCanonicalState);
    final newRevision = newRevisionRaw is int
        ? newRevisionRaw
        : (newRevisionRaw is num
              ? newRevisionRaw.toInt()
              : canonicalState.revision);
    final replayedFromIdempotency = replayedRaw is bool ? replayedRaw : false;
    OwnershipRejectedReason? rejectedReason;
    if (reasonRaw is String) {
      for (final value in OwnershipRejectedReason.values) {
        if (value.name == reasonRaw) {
          rejectedReason = value;
          break;
        }
      }
    }
    return OwnershipCommandResult(
      canonicalState: canonicalState,
      newRevision: newRevision,
      replayedFromIdempotency: replayedFromIdempotency,
      rejectedReason: rejectedReason,
    );
  }
}

/// Ownership conflict simulator hook used by local adapter tests.
abstract class OwnershipConflictSimulator {
  const OwnershipConflictSimulator();

  bool shouldForceConflictForNextCommand();
}

class NoopOwnershipConflictSimulator implements OwnershipConflictSimulator {
  const NoopOwnershipConflictSimulator();

  @override
  bool shouldForceConflictForNextCommand() => false;
}

/// Base command envelope for ownership mutations.
abstract class OwnershipCommand {
  const OwnershipCommand({
    required this.userId,
    required this.sessionId,
    required this.expectedRevision,
    required this.commandId,
  });

  final String userId;
  final String sessionId;
  final int expectedRevision;
  final String commandId;

  String get type;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'userId': userId,
      'sessionId': sessionId,
      'expectedRevision': expectedRevision,
      'commandId': commandId,
      'payload': payloadToJson(),
    };
  }

  Map<String, Object?> payloadToJson();
}

class SetSelectionCommand extends OwnershipCommand {
  const SetSelectionCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.selection,
  });

  final SelectionState selection;

  @override
  String get type => 'setSelection';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{'selection': selection.toJson()};
  }
}

class ResetOwnershipCommand extends OwnershipCommand {
  const ResetOwnershipCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
  });

  @override
  String get type => 'resetOwnership';

  @override
  Map<String, Object?> payloadToJson() => const <String, Object?>{};
}

class SetLoadoutCommand extends OwnershipCommand {
  const SetLoadoutCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.characterId,
    required this.loadout,
  });

  final PlayerCharacterId characterId;
  final EquippedLoadoutDef loadout;

  @override
  String get type => 'setLoadout';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'characterId': characterId.name,
      'loadout': _loadoutToJson(loadout),
    };
  }
}

class SetAbilitySlotCommand extends OwnershipCommand {
  const SetAbilitySlotCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.characterId,
    required this.slot,
    required this.abilityId,
  });

  final PlayerCharacterId characterId;
  final AbilitySlot slot;
  final AbilityKey abilityId;

  @override
  String get type => 'setAbilitySlot';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'characterId': characterId.name,
      'slot': slot.name,
      'abilityId': abilityId,
    };
  }
}

class SetProjectileSpellCommand extends OwnershipCommand {
  const SetProjectileSpellCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.characterId,
    required this.spellId,
  });

  final PlayerCharacterId characterId;
  final ProjectileId spellId;

  @override
  String get type => 'setProjectileSpell';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'characterId': characterId.name,
      'spellId': spellId.name,
    };
  }
}

class EquipGearCommand extends OwnershipCommand {
  const EquipGearCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.characterId,
    required this.slot,
    required this.itemId,
  });

  final PlayerCharacterId characterId;
  final GearSlot slot;
  final Object itemId;

  @override
  String get type => 'equipGear';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'characterId': characterId.name,
      'slot': slot.name,
      ..._gearItemToJson(slot, itemId),
    };
  }
}

class LearnProjectileSpellCommand extends OwnershipCommand {
  const LearnProjectileSpellCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.characterId,
    required this.spellId,
  });

  final PlayerCharacterId characterId;
  final ProjectileId spellId;

  @override
  String get type => 'learnProjectileSpell';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'characterId': characterId.name,
      'spellId': spellId.name,
    };
  }
}

class LearnSpellAbilityCommand extends OwnershipCommand {
  const LearnSpellAbilityCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.characterId,
    required this.abilityId,
  });

  final PlayerCharacterId characterId;
  final AbilityKey abilityId;

  @override
  String get type => 'learnSpellAbility';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'characterId': characterId.name,
      'abilityId': abilityId,
    };
  }
}

class UnlockGearCommand extends OwnershipCommand {
  const UnlockGearCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.slot,
    required this.itemId,
  });

  final GearSlot slot;
  final Object itemId;

  @override
  String get type => 'unlockGear';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'slot': slot.name,
      ..._gearItemToJson(slot, itemId),
    };
  }
}

class AwardRunGoldCommand extends OwnershipCommand {
  const AwardRunGoldCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.runId,
    required this.goldEarned,
  });

  final int runId;
  final int goldEarned;

  @override
  String get type => 'awardRunGold';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{'runId': runId, 'goldEarned': goldEarned};
  }
}

class PurchaseStoreOfferCommand extends OwnershipCommand {
  const PurchaseStoreOfferCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.offerId,
  });

  final String offerId;

  @override
  String get type => 'purchaseStoreOffer';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{'offerId': offerId};
  }
}

class RefreshStoreCommand extends OwnershipCommand {
  const RefreshStoreCommand({
    required super.userId,
    required super.sessionId,
    required super.expectedRevision,
    required super.commandId,
    required this.method,
    this.refreshGrantId,
  });

  final StoreRefreshMethod method;
  final String? refreshGrantId;

  @override
  String get type => 'refreshStore';

  @override
  Map<String, Object?> payloadToJson() {
    return <String, Object?>{
      'method': method.name,
      if (refreshGrantId != null && refreshGrantId!.trim().isNotEmpty)
        'refreshGrantId': refreshGrantId!.trim(),
    };
  }
}

/// Ownership API boundary used by [AppState].
abstract class LoadoutOwnershipApi {
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  });

  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command);

  Future<OwnershipCommandResult> resetOwnership(ResetOwnershipCommand command);

  Future<OwnershipCommandResult> equipGear(EquipGearCommand command);

  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command);

  Future<OwnershipCommandResult> setAbilitySlot(SetAbilitySlotCommand command);

  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  );

  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  );

  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  );

  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command);

  Future<OwnershipCommandResult> awardRunGold(AwardRunGoldCommand command);

  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) {
    throw UnimplementedError('purchaseStoreOffer is not implemented.');
  }

  Future<OwnershipCommandResult> refreshStore(RefreshStoreCommand command) {
    throw UnimplementedError('refreshStore is not implemented.');
  }
}

Map<String, Object?> _loadoutToJson(EquippedLoadoutDef loadout) {
  return <String, Object?>{
    'mask': loadout.mask,
    'mainWeaponId': loadout.mainWeaponId.name,
    'offhandWeaponId': loadout.offhandWeaponId.name,
    'spellBookId': loadout.spellBookId.name,
    'projectileSlotSpellId': loadout.projectileSlotSpellId.name,
    'accessoryId': loadout.accessoryId.name,
    'abilityPrimaryId': loadout.abilityPrimaryId,
    'abilitySecondaryId': loadout.abilitySecondaryId,
    'abilityProjectileId': loadout.abilityProjectileId,
    'abilitySpellId': loadout.abilitySpellId,
    'abilityMobilityId': loadout.abilityMobilityId,
    'abilityJumpId': loadout.abilityJumpId,
  };
}

Map<String, Object?> _gearItemToJson(GearSlot slot, Object itemId) {
  switch (slot) {
    case GearSlot.mainWeapon:
    case GearSlot.offhandWeapon:
      final typed = itemId is WeaponId ? itemId : WeaponId.plainsteel;
      return <String, Object?>{'itemDomain': 'weapon', 'itemId': typed.name};
    case GearSlot.spellBook:
      final typed = itemId is SpellBookId
          ? itemId
          : SpellBookId.apprenticePrimer;
      return <String, Object?>{'itemDomain': 'spellBook', 'itemId': typed.name};
    case GearSlot.accessory:
      final typed = itemId is AccessoryId ? itemId : AccessoryId.strengthBelt;
      return <String, Object?>{'itemDomain': 'accessory', 'itemId': typed.name};
  }
}
