import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/meta/spell_list.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/meta_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/selection_store.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  group('AppState loadout mask normalization', () {
    test('buildRunStartArgs uses character-authored loadout mask', () {
      final appState = AppState();

      final args = appState.buildRunStartArgs(seed: 123);

      expect(args.equippedLoadout.mask, LoadoutSlotMask.all);
    });

    test(
      'setLoadout normalizes legacy mask to selected character mask',
      () async {
        final selectionStore = _MemorySelectionStore();
        final appState = AppState(selectionStore: selectionStore);

        await appState.setLoadout(
          const EquippedLoadoutDef(mask: LoadoutSlotMask.defaultMask),
        );

        expect(_selectedLoadout(appState.selection).mask, LoadoutSlotMask.all);
        expect(
          _selectedLoadout(selectionStore.saved).mask,
          LoadoutSlotMask.all,
        );
      },
    );

    test('setLoadout repairs unknown ability ids', () async {
      final selectionStore = _MemorySelectionStore();
      final appState = AppState(selectionStore: selectionStore);

      await appState.setLoadout(
        const EquippedLoadoutDef(abilityPrimaryId: 'common.unarmed_strike'),
      );

      expect(
        _selectedLoadout(appState.selection).abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
      expect(
        _selectedLoadout(selectionStore.saved).abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
    });

    test(
      'setLoadout keeps learned spell-slot spell from default spell list',
      () async {
        final selectionStore = _MemorySelectionStore();
        final appState = AppState(selectionStore: selectionStore);

        await appState.setLoadout(
          const EquippedLoadoutDef(abilitySpellId: 'eloise.mana_infusion'),
        );

        expect(
          _selectedLoadout(appState.selection).abilitySpellId,
          'eloise.mana_infusion',
        );
        expect(
          _selectedLoadout(selectionStore.saved).abilitySpellId,
          'eloise.mana_infusion',
        );
      },
    );

    test(
      'setLoadout keeps learned projectile spell from default spell list',
      () async {
        final selectionStore = _MemorySelectionStore();
        final appState = AppState(selectionStore: selectionStore);

        await appState.setLoadout(
          const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.iceBolt),
        );

        expect(
          _selectedLoadout(appState.selection).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
        expect(
          _selectedLoadout(selectionStore.saved).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
      },
    );

    test(
      'setLoadout stale projectile spell repairs to first learned spell only',
      () async {
        final selectionStore = _MemorySelectionStore();
        final baseMeta = const MetaService().createNew();
        final metaWithCustomSpellList = baseMeta
            .setEquippedFor(
              PlayerCharacterId.eloise,
              baseMeta
                  .equippedFor(PlayerCharacterId.eloise)
                  .copyWith(spellBookId: SpellBookId.epicSpellBook),
            )
            .setSpellListFor(
              PlayerCharacterId.eloise,
              const SpellList(
                learnedProjectileSpellIds: <ProjectileId>{
                  ProjectileId.iceBolt,
                  ProjectileId.fireBolt,
                },
                learnedSpellAbilityIds: <String>{'eloise.arcane_haste'},
              ),
            );
        final metaStore = _MemoryMetaStore(saved: metaWithCustomSpellList);
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
          userProfileStore: _MemoryUserProfileStore(),
        );

        await appState.bootstrap(force: true);
        await appState.setLoadout(
          const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.throwingAxe,
          ),
        );

        expect(
          _selectedLoadout(appState.selection).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
        expect(
          _selectedLoadout(selectionStore.saved).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
      },
    );

    test(
      'equipGear syncs selected loadout projectile and spellbook sources',
      () async {
        final selectionStore = _MemorySelectionStore();
        final metaStore = _MemoryMetaStore(
          saved: const MetaService().createNew(),
        );
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.throwingWeapon,
          itemId: ProjectileId.throwingAxe,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );

        expect(
          _selectedLoadout(appState.selection).projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          _selectedLoadout(appState.selection).spellBookId,
          SpellBookId.solidSpellBook,
        );
        expect(
          _selectedLoadout(selectionStore.saved).projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          _selectedLoadout(selectionStore.saved).spellBookId,
          SpellBookId.solidSpellBook,
        );
      },
    );

    test(
      'equipGear spellbook swap does not mutate learned spell-slot selection',
      () async {
        final selectionStore = _MemorySelectionStore();
        final baseMeta = const MetaService().createNew();
        final metaStore = _MemoryMetaStore(
          saved: baseMeta.setSpellListFor(
            PlayerCharacterId.eloise,
            const SpellList(
              learnedProjectileSpellIds: <ProjectileId>{ProjectileId.fireBolt},
              learnedSpellAbilityIds: <String>{
                'eloise.arcane_haste',
                'eloise.vital_surge',
              },
            ),
          ),
        );
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
          userProfileStore: _MemoryUserProfileStore(),
        );
        await appState.bootstrap(force: true);

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );
        await appState.setLoadout(
          const EquippedLoadoutDef(abilitySpellId: 'eloise.vital_surge'),
        );
        expect(
          _selectedLoadout(appState.selection).abilitySpellId,
          'eloise.vital_surge',
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.basicSpellBook,
        );

        expect(
          _selectedLoadout(appState.selection).abilitySpellId,
          'eloise.vital_surge',
        );
        expect(
          _selectedLoadout(selectionStore.saved).abilitySpellId,
          'eloise.vital_surge',
        );
      },
    );

    test(
      'equipGear spellbook swap does not mutate learned projectile spell',
      () async {
        final selectionStore = _MemorySelectionStore();
        final baseMeta = const MetaService().createNew();
        final metaStore = _MemoryMetaStore(
          saved: baseMeta.setSpellListFor(
            PlayerCharacterId.eloise,
            const SpellList(
              learnedProjectileSpellIds: <ProjectileId>{
                ProjectileId.fireBolt,
                ProjectileId.iceBolt,
              },
              learnedSpellAbilityIds: <String>{'eloise.arcane_haste'},
            ),
          ),
        );
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
          userProfileStore: _MemoryUserProfileStore(),
        );
        await appState.bootstrap(force: true);

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );
        await appState.setLoadout(
          const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.iceBolt),
        );
        expect(
          _selectedLoadout(appState.selection).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.basicSpellBook,
        );

        expect(
          _selectedLoadout(appState.selection).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
        expect(
          _selectedLoadout(selectionStore.saved).projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
      },
    );

    test(
      'bootstrap syncs stale selection gear ids from persisted meta',
      () async {
        const service = MetaService();
        var meta = service.createNew();
        meta = service.equip(
          meta,
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.throwingWeapon,
          itemId: ProjectileId.throwingAxe,
        );
        meta = service.equip(
          meta,
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );

        final selectionStore = _MemorySelectionStore(
          saved: SelectionState(
            selectedLevelId: SelectionState.defaults.selectedLevelId,
            selectedRunType: SelectionState.defaults.selectedRunType,
            selectedCharacterId: PlayerCharacterId.eloise,
            loadoutsByCharacter: _loadoutsWithSelected(
              characterId: PlayerCharacterId.eloise,
              loadout: EquippedLoadoutDef(
                projectileId: ProjectileId.throwingKnife,
                spellBookId: SpellBookId.basicSpellBook,
              ),
            ),
            buildName: SelectionState.defaultBuildName,
          ),
        );
        final metaStore = _MemoryMetaStore(saved: meta);
        final profileStore = _MemoryUserProfileStore();
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
          userProfileStore: profileStore,
        );

        await appState.bootstrap(force: true);

        expect(
          _selectedLoadout(appState.selection).projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          _selectedLoadout(appState.selection).spellBookId,
          SpellBookId.solidSpellBook,
        );
        expect(
          _selectedLoadout(selectionStore.saved).projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          _selectedLoadout(selectionStore.saved).spellBookId,
          SpellBookId.solidSpellBook,
        );
      },
    );

    test('bootstrap repairs unknown saved ability ids', () async {
      final selectionStore = _MemorySelectionStore(
        saved: SelectionState(
          selectedLevelId: SelectionState.defaults.selectedLevelId,
          selectedRunType: SelectionState.defaults.selectedRunType,
          selectedCharacterId: PlayerCharacterId.eloise,
          loadoutsByCharacter: _loadoutsWithSelected(
            characterId: PlayerCharacterId.eloise,
            loadout: const EquippedLoadoutDef(
              abilityPrimaryId: 'common.unarmed_strike',
            ),
          ),
          buildName: SelectionState.defaultBuildName,
        ),
      );
      final metaStore = _MemoryMetaStore(
        saved: const MetaService().createNew(),
      );
      final profileStore = _MemoryUserProfileStore();
      final appState = AppState(
        selectionStore: selectionStore,
        metaStore: metaStore,
        userProfileStore: profileStore,
      );

      await appState.bootstrap(force: true);

      expect(
        _selectedLoadout(appState.selection).abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
      expect(
        _selectedLoadout(selectionStore.saved).abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
    });
  });
}

EquippedLoadoutDef _selectedLoadout(SelectionState state) {
  return state.loadoutFor(state.selectedCharacterId);
}

Map<PlayerCharacterId, EquippedLoadoutDef> _loadoutsWithSelected({
  required PlayerCharacterId characterId,
  required EquippedLoadoutDef loadout,
}) {
  return <PlayerCharacterId, EquippedLoadoutDef>{
    for (final id in PlayerCharacterId.values)
      id: id == characterId ? loadout : const EquippedLoadoutDef(),
  };
}

class _MemorySelectionStore extends SelectionStore {
  _MemorySelectionStore({SelectionState? saved})
    : saved = saved ?? SelectionState.defaults;

  SelectionState saved;

  @override
  Future<SelectionState> load() async => saved;

  @override
  Future<void> save(SelectionState state) async {
    saved = state;
  }
}

class _MemoryMetaStore extends MetaStore {
  _MemoryMetaStore({required this.saved});

  MetaState saved;

  @override
  Future<MetaState> load(MetaService service) async => saved;

  @override
  Future<void> save(MetaState state) async {
    saved = state;
  }
}

class _MemoryUserProfileStore extends UserProfileStore {
  _MemoryUserProfileStore({UserProfile? saved})
    : saved = saved ?? UserProfile.empty();

  UserProfile saved;

  @override
  Future<UserProfile> load() async => saved;

  @override
  Future<void> save(UserProfile profile) async {
    saved = profile;
  }

  @override
  UserProfile createFresh() => saved;
}
