import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/state/firebase_loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  test('loadCanonicalState decodes wrapped canonical payload', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource();
    final expected = OwnershipCanonicalState(
      profileId: 'p1',
      revision: 7,
      selection: SelectionState.defaults,
      meta: const MetaService().createNew(),
      progression: const ProgressionState(gold: 42),
    );
    source.loadCanonicalResponse = <String, dynamic>{
      'canonicalState': expected.toJson(),
    };
    final api = FirebaseLoadoutOwnershipApi(source: source);

    final actual = await api.loadCanonicalState(userId: 'u1', sessionId: 's1');

    expect(actual.profileId, expected.profileId);
    expect(actual.revision, expected.revision);
    expect(actual.progression.gold, 42);
  });

  test('setAbilitySlot forwards typed command to Firebase source', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource();
    final canonical = OwnershipCanonicalState(
      profileId: 'p1',
      revision: 1,
      selection: SelectionState.defaults,
      meta: const MetaService().createNew(),
      progression: ProgressionState.initial,
    );
    source.commandResponse = OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    ).toJson();
    final api = FirebaseLoadoutOwnershipApi(source: source);

    final result = await api.setAbilitySlot(
      const SetAbilitySlotCommand(
        userId: 'u1',
        sessionId: 's1',
        expectedRevision: 0,
        commandId: 'cmd-1',
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.spell,
        abilityId: 'eloise.focus',
      ),
    );

    expect(result.accepted, isTrue);
    expect(source.lastCommand?.type, 'setAbilitySlot');
  });

  test('throws when Firebase source fails and fallback is disabled', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource()
      ..commandError = StateError('backend unavailable');
    final api = FirebaseLoadoutOwnershipApi(source: source);

    await expectLater(
      () => api.unlockGear(
        const UnlockGearCommand(
          userId: 'u1',
          sessionId: 's1',
          expectedRevision: 0,
          commandId: 'cmd-fallback',
          slot: GearSlot.accessory,
          itemId: AccessoryId.strengthBelt,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('refreshStore forwards typed command to Firebase source', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource();
    final canonical = OwnershipCanonicalState(
      profileId: 'p1',
      revision: 2,
      selection: SelectionState.defaults,
      meta: const MetaService().createNew(),
      progression: ProgressionState.initial,
    );
    source.commandResponse = OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    ).toJson();
    final api = FirebaseLoadoutOwnershipApi(source: source);

    final result = await api.refreshStore(
      const RefreshStoreCommand(
        userId: 'u1',
        sessionId: 's1',
        expectedRevision: 1,
        commandId: 'cmd-refresh',
        method: StoreRefreshMethod.gold,
      ),
    );

    expect(result.accepted, isTrue);
    expect(source.lastCommand?.type, 'refreshStore');
  });
}

class _FakeFirebaseLoadoutOwnershipSource
    implements FirebaseLoadoutOwnershipSource {
  Map<String, dynamic> loadCanonicalResponse = <String, dynamic>{};
  Map<String, dynamic> commandResponse = <String, dynamic>{};
  Object? loadCanonicalError;
  Object? commandError;
  OwnershipCommand? lastCommand;

  @override
  Future<Map<String, dynamic>> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    final error = loadCanonicalError;
    if (error != null) {
      throw error;
    }
    return loadCanonicalResponse;
  }

  @override
  Future<Map<String, dynamic>> executeCommand({
    required OwnershipCommand command,
  }) async {
    lastCommand = command;
    final error = commandError;
    if (error != null) {
      throw error;
    }
    return commandResponse;
  }
}
