import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_runner/ui/state/ownership/ownership_outbox_store.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_pending_command.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_sync_policy.dart';

void main() {
  group('SharedPrefsOwnershipOutboxStore', () {
    late SharedPrefsOwnershipOutboxStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = SharedPrefsOwnershipOutboxStore();
    });

    test('upsertCoalesced stores and replaces by coalesceKey', () async {
      await store.upsertCoalesced(command: _command(key: 'selection:level'));
      await store.upsertCoalesced(
        command: _command(
          key: 'selection:level',
          updatedAtMs: 200,
          payload: <String, Object?>{'selectedLevelId': 'forest'},
        ),
      );

      final all = await store.loadAll(ownerUserId: 'uid_test');
      expect(all, hasLength(1));
      expect(all.single.coalesceKey, 'selection:level');
      expect(all.single.createdAtMs, 100);
      expect(all.single.updatedAtMs, 200);
      expect(all.single.payloadJson['selectedLevelId'], 'forest');
    });

    test('drops unscoped legacy rows and reads scoped stored rows', () async {
      final prefs = await SharedPreferences.getInstance();
      final unscopedLegacyRow = _command(key: 'selection:runMode').toJson()
        ..remove('ownerUserId');
      await prefs.setString(
        SharedPrefsOwnershipOutboxStore.storageKey,
        jsonEncode(<Object?>[unscopedLegacyRow]),
      );

      final legacyLoaded = await store.loadAll(ownerUserId: 'uid_test');
      expect(legacyLoaded, isEmpty);

      await prefs.setString(
        SharedPrefsOwnershipOutboxStore.storageKey,
        jsonEncode(<String, Object?>{
          'version': 2,
          'entries': <Object?>[
            _command(key: 'gear:eloise:mainWeapon').toJson(),
          ],
        }),
      );
      final wrappedLoaded = await store.loadAll(ownerUserId: 'uid_test');
      expect(wrappedLoaded, hasLength(1));
      expect(wrappedLoaded.single.coalesceKey, 'gear:eloise:mainWeapon');
    });

    test('keeps same coalesce keys isolated by owner UID', () async {
      await store.upsertCoalesced(
        command: _command(
          ownerUserId: 'uid_a',
          key: 'selection',
          payload: <String, Object?>{'selectedLevelId': 'field'},
        ),
      );
      await store.upsertCoalesced(
        command: _command(
          ownerUserId: 'uid_b',
          key: 'selection',
          payload: <String, Object?>{'selectedLevelId': 'forest'},
        ),
      );

      final firstOwner = await store.loadByCoalesceKey(
        ownerUserId: 'uid_a',
        coalesceKey: 'selection',
      );
      final secondOwner = await store.loadByCoalesceKey(
        ownerUserId: 'uid_b',
        coalesceKey: 'selection',
      );

      expect(firstOwner?.payloadJson['selectedLevelId'], 'field');
      expect(secondOwner?.payloadJson['selectedLevelId'], 'forest');
    });

    test('ignores malformed rows and keeps valid rows', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPrefsOwnershipOutboxStore.storageKey,
        jsonEncode(<String, Object?>{
          'version': 2,
          'entries': <Object?>[
            <String, Object?>{'coalesceKey': 7},
            _command(key: 'selection:character').toJson(),
          ],
        }),
      );

      final loaded = await store.loadAll(ownerUserId: 'uid_test');
      expect(loaded, hasLength(1));
      expect(loaded.single.coalesceKey, 'selection:character');
    });

    test('removeByCoalesceKey and clear delete entries', () async {
      await store.upsertCoalesced(command: _command(key: 'a'));
      await store.upsertCoalesced(command: _command(key: 'b'));

      await store.removeByCoalesceKey(
        ownerUserId: 'uid_test',
        coalesceKey: 'a',
      );
      final afterRemove = await store.loadAll(ownerUserId: 'uid_test');
      expect(afterRemove.map((e) => e.coalesceKey), ['b']);

      await store.clear();
      final afterClear = await store.loadAll(ownerUserId: 'uid_test');
      expect(afterClear, isEmpty);
    });
  });
}

OwnershipPendingCommand _command({
  required String key,
  String ownerUserId = 'uid_test',
  int createdAtMs = 100,
  int updatedAtMs = 100,
  Map<String, Object?> payload = const <String, Object?>{
    'selectedLevelId': 'field',
  },
}) {
  return OwnershipPendingCommand(
    ownerUserId: ownerUserId,
    coalesceKey: key,
    commandType: OwnershipPendingCommandType.setSelection,
    policyTier: OwnershipSyncTier.selectionFastSync,
    payloadJson: payload,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
  );
}
