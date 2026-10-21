import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/app/app_services.dart';
import 'package:rpg_runner/ui/bootstrap/app_bootstrapper.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_sync_policy.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/state/run/run_start_remote_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/app_startup_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> developer() async {
    final state = AppState.developer(store: SharedPrefsDeveloperProfileStore());
    addTearDown(state.dispose);
    await state.bootstrap();
    return state;
  }

  test(
    'unlocks current gear and player abilities without an online identity',
    () async {
      final state = await developer();
      expect(state.authSession.isAuthenticated, isFalse);
      expect(state.profile.displayName, 'Developer');
      expect(state.profile.namePromptCompleted, isTrue);
      expect(state.progression.gold, 0);
      for (final slot in GearSlot.values) {
        final candidates = const MetaService().candidatesForSlot(
          state.meta,
          slot,
        );
        expect(candidates, isNotEmpty);
        expect(candidates.every((candidate) => candidate.isUnlocked), isTrue);
      }
      for (final id in PlayerCharacterId.values) {
        final ownership = state.meta.abilityOwnershipFor(id);
        expect(
          ownership.learnedProjectileSpellIds,
          containsAll(playerEquippableProjectileIds),
        );
        for (final slot in AbilitySlot.values) {
          final abilities = ownership.learnedAbilityIdsForSlot(slot);
          expect(abilities, isNotEmpty);
          expect(
            abilities.any((id) => id.startsWith('common.enemy_')),
            isFalse,
          );
        }
        await state.setCharacter(id);
        final run = await state.prepareRunStartDescriptor();
        expect(run.playerCharacterId, id);
        expect(
          run.equippedLoadout.mask,
          PlayerCharacterRegistry.resolve(id).catalog.loadoutSlotMask,
        );
        expect(run.isDeveloperPractice, isTrue);
        expect(run.copyWith(seed: 123).isDeveloperPractice, isTrue);
      }
    },
  );

  test(
    'loadouts, character, level and build name survive profile reconstruction',
    () async {
      final state = await developer();
      final character = PlayerCharacterId.values.last;
      final candidate =
          const MetaService()
                  .candidatesForSlot(state.meta, GearSlot.mainWeapon)
                  .last
                  .id
              as WeaponId;
      await state.setCharacter(character);
      await state.setLevel(LevelId.forest);
      await state.setBuildName('Phone test');
      await state.equipGear(
        characterId: character,
        slot: GearSlot.mainWeapon,
        itemId: candidate,
      );
      await state.setAbilitySlot(
        characterId: character,
        slot: AbilitySlot.mobility,
        abilityId: state.meta
            .abilityOwnershipFor(character)
            .learnedAbilityIdsForSlot(AbilitySlot.mobility)
            .last,
      );
      await state.flushOwnershipEdits(
        trigger: OwnershipFlushTrigger.lifecyclePaused,
      );
      final restored = await developer();
      expect(restored.selection.toJson(), state.selection.toJson());
      expect(restored.meta.equippedFor(character).mainWeaponId, candidate);
      expect(restored.selection.selectedRunMode, RunMode.practice);
    },
  );

  test(
    'local starts and restarts use fresh identifiers without remote warmup',
    () async {
      final state = await developer();
      state.startWarmup();
      await state.startRunTicketPrefetchForCurrentSelection();
      final first = await state.prepareRunStartDescriptor();
      final second = await state.prepareRunStartDescriptor(
        expectedMode: first.runMode,
        expectedLevelId: first.levelId,
      );
      expect(first.runSessionId, startsWith('developer_'));
      expect(second.runSessionId, isNot(first.runSessionId));
      expect(first.seed, greaterThan(0));
      expect(first.tickHz, 60);
      expect(first.boardId, isNull);
      expect(first.ghostReplayBootstrap, isNull);
      expect(second.isDeveloperPractice, isTrue);
    },
  );

  test('rejects online modes, ghosts, rewards and account actions at state boundary', () async {
    final state = await developer();
    for (final mode in [RunMode.competitive, RunMode.weekly]) {
      await expectLater(
        state.setRunMode(mode),
        throwsA(isA<RunStartRemoteException>()),
      );
      await expectLater(
        state.setRunModeAndLevel(runMode: mode, levelId: LevelId.forest),
        throwsA(isA<RunStartRemoteException>()),
      );
      await expectLater(
        state.prepareRunStartDescriptor(expectedMode: mode),
        throwsA(isA<RunStartRemoteException>()),
      );
    }
    await expectLater(
      state.prepareRunStartDescriptor(ghostEntryId: 'ghost'),
      throwsA(isA<RunStartRemoteException>()),
    );
    await expectLater(
      state.journalRunReplay(
        runSessionId: 'dev',
        runMode: RunMode.practice,
        replayFilePath: 'unused',
        canonicalSha256: 'unused',
        contentLengthBytes: 1,
      ),
      throwsStateError,
    );
    await expectLater(state.processPendingRunSubmissions(), throwsStateError);
    await expectLater(
      state.purchaseStoreOffer(offerId: 'unused'),
      throwsStateError,
    );
    await expectLater(state.updateDisplayName('Changed'), throwsStateError);
    await expectLater(state.deleteAccountAndData(), throwsStateError);
    expect(state.selection.selectedRunMode, RunMode.practice);
    expect(state.progression.gold, 0);
    expect(
      (await SharedPreferences.getInstance()).getKeys().every(
        (key) => key.startsWith('developer_practice.'),
      ),
      isTrue,
    );
  });

  test(
    'repairs enemy and wrong-slot abilities without widening character slots',
    () async {
      final state = await developer();
      await state.setAbilitySlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.primary,
        abilityId: 'eloise.aegis_riposte',
      );
      expect(
        state.selection.loadoutFor(PlayerCharacterId.eloise).abilityPrimaryId,
        SelectionState.defaults
            .loadoutFor(PlayerCharacterId.eloise)
            .abilityPrimaryId,
      );
      expect(
        (await state.prepareRunStartDescriptor()).isDeveloperPractice,
        isTrue,
      );
    },
  );

  test(
    'saved developer boot bypasses failing online initialization entirely',
    () async {
      final store = SharedPrefsDeveloperProfileStore();
      await store.saveEnabled(true);
      final services = AppServices(
        initialize: () async => throw StateError('Backend unavailable'),
        createAppState: () =>
            throw StateError('Must not create online clients'),
        developerProfileStore: store,
      );
      addTearDown(services.dispose);
      expect(
        (await const AppBootstrapper().run(services, force: false)).ok,
        isTrue,
      );
      expect(
        (await const AppBootstrapper().run(services, force: true)).ok,
        isTrue,
      );
      expect(services.appState.isDeveloperMode, isTrue);
    },
  );

  test(
    'switching isolates profiles and preserves normal account state',
    () async {
      final fixture = StartupFixture();
      final store = SharedPrefsDeveloperProfileStore();
      final services = AppServices(
        initialize: () async {},
        createAppState: () => AppState(
          authApi: fixture.auth,
          userProfileRemoteApi: fixture.profile,
          loadoutOwnershipApi: fixture.ownership,
        ),
        developerProfileStore: store,
      );
      addTearDown(services.dispose);
      await (await services.initialize()).bootstrap();
      final normal = services.appState;
      final normalSelection = normal.selection.toJson();
      final profileLoads = fixture.profile.calls;
      await services.setDeveloperMode(true);
      await services.appState.setBuildName('Local only');
      await services.appState.setLevel(LevelId.forest);
      expect(await store.loadEnabled(), isTrue);
      expect(fixture.profile.calls, profileLoads);
      expect(normal.selection.toJson(), normalSelection);
      await services.setDeveloperMode(false);
      expect(services.appState.isDeveloperMode, isFalse);
      expect(services.appState.selection.toJson(), normalSelection);
      expect(await store.loadEnabled(), isFalse);
      await services.setDeveloperMode(true);
      expect(services.appState.selection.buildName, 'Local only');
    },
  );

  for (final savedDisabled in [false, true]) {
    test(
      'explicit local startup skips auth with ${savedDisabled ? 'disabled' : 'missing'} preference',
      () async {
        final fixture = StartupFixture();
        final store = SharedPrefsDeveloperProfileStore();
        if (savedDisabled) await store.saveEnabled(false);
        var onlineInitializations = 0;
        final services = AppServices(
          initialize: () async {
            onlineInitializations++;
          },
          createAppState: () => AppState(
            authApi: fixture.auth,
            userProfileRemoteApi: fixture.profile,
            loadoutOwnershipApi: fixture.ownership,
          ),
          developerProfileStore: store,
          startInDeveloperMode: true,
        );
        addTearDown(services.dispose);
        const bootstrapper = AppBootstrapper();
        expect((await bootstrapper.run(services, force: false)).ok, isTrue);
        expect((await bootstrapper.run(services, force: true)).ok, isTrue);
        expect(services.appState.isDeveloperMode, isTrue);
        expect(services.appState.authSession.isAuthenticated, isFalse);
        expect(
          (await services.appState.prepareRunStartDescriptor())
              .isDeveloperPractice,
          isTrue,
        );
        expect(onlineInitializations, 0);
        expect(fixture.auth.calls, 0);
        expect(await store.loadEnabled(), isFalse);

        await services.setDeveloperMode(false);
        expect((await bootstrapper.run(services, force: true)).ok, isTrue);
        expect(services.appState.isDeveloperMode, isFalse);
        expect(onlineInitializations, 1);
        expect(fixture.auth.calls, greaterThan(0));
      },
    );
  }

  test('local startup request requires developer support', () async {
    final fixture = StartupFixture();
    final services = AppServices(
      initialize: () async {},
      createAppState: () => AppState(
        authApi: fixture.auth,
        userProfileRemoteApi: fixture.profile,
        loadoutOwnershipApi: fixture.ownership,
      ),
      startInDeveloperMode: true,
    );
    addTearDown(services.dispose);
    expect(
      (await const AppBootstrapper().run(services, force: false)).ok,
      isTrue,
    );
    expect(services.developerModeAvailable, isFalse);
    expect(services.appState.isDeveloperMode, isFalse);
    expect(fixture.auth.calls, 1);
  });

  test('failed switch back keeps developer profile and saved toggle', () async {
    final store = SharedPrefsDeveloperProfileStore();
    await store.saveEnabled(true);
    final services = AppServices(
      initialize: () async => throw StateError('offline'),
      createAppState: () => throw StateError('unexpected'),
      developerProfileStore: store,
    );
    addTearDown(services.dispose);
    await (await services.initialize()).bootstrap();
    final previous = services.appState;
    await expectLater(services.setDeveloperMode(false), throwsStateError);
    expect(services.appState, same(previous));
    expect(await store.loadEnabled(), isTrue);
    expect(services.isSwitchingProfile, isFalse);
  });

  test('unconfigured builds ignore a saved developer preference', () async {
    await SharedPrefsDeveloperProfileStore().saveEnabled(true);
    final fixture = StartupFixture();
    addTearDown(fixture.services.dispose);
    final state = await fixture.services.initialize();
    expect(state.isDeveloperMode, isFalse);
    expect(fixture.services.developerModeAvailable, isFalse);
    await expectLater(
      fixture.services.setDeveloperMode(true),
      throwsStateError,
    );
  });

  test('damaged local selection restores usable defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('developer_practice.selection.v1', '{broken');
    final state = await developer();
    expect(
      (await state.prepareRunStartDescriptor()).isDeveloperPractice,
      isTrue,
    );
  });

  test(
    'ordered saves survive rapid edits and flush retries a failed write',
    () async {
      final store = _ControlledStore()..selectionGate = Completer<void>();
      final state = AppState.developer(store: store);
      addTearDown(state.dispose);
      await state.bootstrap();
      final first = state.setBuildName('First');
      final second = state.setBuildName('Second');
      await Future<void>.delayed(Duration.zero);
      expect(store.selectionWrites, 1);
      store.selectionGate!.complete();
      await Future.wait([first, second]);
      expect((await store.loadSelection()).buildName, 'Second');
      store.failSelection = true;
      await expectLater(state.setBuildName('Retry'), throwsStateError);
      store.failSelection = false;
      await state.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);
      expect((await store.loadSelection()).buildName, 'Retry');
    },
  );

  test('failed toggle persistence leaves the normal profile usable', () async {
    final fixture = StartupFixture();
    final store = _ControlledStore()..failEnabled = true;
    final services = AppServices(
      initialize: () async {},
      createAppState: () => AppState(
        authApi: fixture.auth,
        userProfileRemoteApi: fixture.profile,
        loadoutOwnershipApi: fixture.ownership,
      ),
      developerProfileStore: store,
    );
    addTearDown(services.dispose);
    await (await services.initialize()).bootstrap();
    final normal = services.appState;
    await expectLater(services.setDeveloperMode(true), throwsStateError);
    expect(services.appState, same(normal));
    expect(await store.loadEnabled(), isFalse);
    await normal.bootstrap(force: true);
    store.failEnabled = false;
    await services.setDeveloperMode(true);
    expect(services.appState.isDeveloperMode, isTrue);
  });
}

class _ControlledStore extends SharedPrefsDeveloperProfileStore {
  Completer<void>? selectionGate;
  int selectionWrites = 0;
  bool failSelection = false;
  bool failEnabled = false;

  @override
  Future<void> saveSelection(SelectionState selection) async {
    selectionWrites++;
    await selectionGate?.future;
    if (failSelection) throw StateError('Disk full');
    await super.saveSelection(selection);
  }

  @override
  Future<void> saveEnabled(bool enabled) async {
    if (failEnabled) throw StateError('Disk full');
    await super.saveEnabled(enabled);
  }
}
