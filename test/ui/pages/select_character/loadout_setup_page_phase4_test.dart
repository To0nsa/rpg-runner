import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/ui/state/ownership/enemy_defeats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/loadout_setup_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_skill_icon_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';
import 'package:game_presentation/game_icon.dart';
import 'package:rpg_runner/ui/controls/action_button.dart';
import 'package:rpg_runner/ui/controls/ability_slot_visual_spec.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/skills/skills_radial_pane.dart';

void main() {
  testWidgets(
    'Training tab keeps appbar, filters opponents, resets death and leaving',
    (tester) async {
      final appState = await _bootstrappedAppState(
        progression: ProgressionState.initial.copyWith(
          enemyDefeats: EnemyDefeats(
            byEnemy: {'derf': 10, 'grojib': 9, 'bringerOfDeath': 10},
          ),
        ),
      );
      addTearDown(appState.dispose);
      final originalProgression = appState.progression;
      await tester.pumpWidget(_TestApp(appState: appState));
      await tester.pumpAndSettle();
      expect(find.byType(Tab), findsNWidgets(3));
      Future<RunnerFlameGame> enter() async {
        await tester.tap(find.byType(Tab).at(2));
        await tester.pump();
        final game = tester
            .widget<GameWidget<RunnerFlameGame>>(
              find.byType(GameWidget<RunnerFlameGame>),
            )
            .game!;
        await _trainingReady(tester, game);
        expect(game.loadState.value.phase, RunLoadPhase.worldReady);
        expect(find.byType(Tab), findsNWidgets(3));
        return game;
      }

      final first = await enter();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(first.controller.snapshot.paused, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      if (find.text('Resume').evaluate().isNotEmpty) {
        await tester.tap(find.text('Resume'));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('training-enemy-settings')));
      // Flame keeps scheduling frames while its controller is paused.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Derf'), findsOneWidget);
      expect(find.text('Grojib'), findsNothing);
      expect(find.text('Bringer of Death'), findsNothing);
      await tester.tap(find.text('Derf'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Drive real Core movement off the left edge to exercise the death UI.
      first.controller.setPaused(false);
      for (var i = 0; i < 360 && !first.controller.snapshot.gameOver; i++) {
        first.controller.enqueue(
          MoveAxisCommand(tick: first.controller.tick + 1, axis: -1),
        );
        first.controller.advanceFrame(1 / 60);
      }
      await tester.pump();
      expect(first.controller.snapshot.gameOver, isTrue);
      expect(find.byKey(const ValueKey('training-reset')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('training-reset')));
      await tester.pump();
      final reset = tester
          .widget<GameWidget<RunnerFlameGame>>(
            find.byType(GameWidget<RunnerFlameGame>),
          )
          .game!;
      expect(reset, isNot(same(first)));
      await _trainingReady(tester, reset);
      expect(reset.controller.snapshot.gameOver, isFalse);
      expect(
        reset.controller.snapshot.entities.where(
          (e) => e.kind == EntityKind.enemy,
        ),
        isEmpty,
      );
      expect(find.byTooltip('Choose training opponent'), findsOneWidget);
      await tester.tap(find.byType(Tab).first);
      await tester.pumpAndSettle();
      final oldTick = reset.controller.tick;
      reset.controller.advanceFrame(1);
      expect(reset.controller.tick, oldTick);
      final fresh = await enter();
      expect(fresh, isNot(same(reset)));
      expect(find.byTooltip('Choose training opponent'), findsOneWidget);
      expect(
        fresh.controller.snapshot.entities.where(
          (e) => e.kind == EntityKind.enemy,
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(appState.progression, same(originalProgression));
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'GearsTab shows + Town shortcut and navigates after confirmation',
    (tester) async {
      final appState = await _bootstrappedAppState();
      await tester.pumpWidget(_TestApp(appState: appState));
      await tester.pumpAndSettle();

      final shortcut = find.byKey(const ValueKey<String>('gear-town-shortcut'));
      expect(shortcut, findsAtLeastNWidgets(1));

      await tester.tap(shortcut.first);
      await tester.pumpAndSettle();

      expect(find.text('Visit Town store?'), findsOneWidget);
      await tester.tap(find.text('Go to Town'));
      await tester.pumpAndSettle();

      expect(find.text('town-page-marker'), findsOneWidget);
    },
  );

  testWidgets(
    'SkillsTab shows locked entries and locked details Find in Town CTA',
    (tester) async {
      final appState = await _bootstrappedAppState();
      await tester.pumpWidget(_TestApp(appState: appState));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Bloodletter Slash'), findsOneWidget);
      final radial = find.byType(SkillsRadialPane);
      expect(
        find.descendant(of: radial, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(of: radial, matching: find.byType(GameIcon)),
        findsNothing,
      );
      expect(
        find.descendant(of: radial, matching: find.byType(ActionButton)),
        findsNWidgets(6),
      );
      // Skill-list and detail artwork is separate from control symbols.
      expect(find.byType(GameIcon), findsWidgets);
      await tester.tap(
        find.descendant(
          of: radial,
          matching: find.byIcon(
            abilityRadialLayoutSpec.slotSpec(AbilitySlot.projectile).icon,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SkillsRadialPane>(radial).selectedSlot,
        AbilitySlot.projectile,
      );
      await tester.tap(
        find.descendant(
          of: radial,
          matching: find.byIcon(
            abilityRadialLayoutSpec.slotSpec(AbilitySlot.primary).icon,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>(
            'skill-status-locked-eloise.bloodletter_slash',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Bloodletter Slash'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unlock this skill in Town to view full details.'),
        findsOneWidget,
      );
      expect(find.text('Find in Town'), findsOneWidget);

      await tester.tap(find.text('Find in Town'));
      await tester.pumpAndSettle();

      expect(find.text('town-page-marker'), findsOneWidget);
    },
  );
}

Future<void> _trainingReady(WidgetTester tester, RunnerFlameGame game) async {
  for (
    var i = 0;
    i < 800 && game.loadState.value.phase != RunLoadPhase.worldReady;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(tester.takeException(), isNull);
  }
  expect(game.loadState.value.phase, RunLoadPhase.worldReady);
  await tester.pump();
}

Future<AppState> _bootstrappedAppState({
  ProgressionState progression = ProgressionState.initial,
}) async {
  final appState = AppState(
    authApi: const _StaticAuthApi(),
    loadoutOwnershipApi: _NoopOwnershipApi(progression: progression),
  );
  await appState.bootstrap(force: true);
  return appState;
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: <ThemeExtension<dynamic>>[
            UiTokens.standard,
            UiButtonTheme.standard,
            UiSkillIconTheme.standard,
          ],
        ),
        home: const LoadoutSetupPage(),
        routes: <String, WidgetBuilder>{
          UiRoutes.town: (_) => const _RouteMarker('town-page-marker'),
        },
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _StaticAuthApi implements AuthApi {
  const _StaticAuthApi();

  static const AuthSession _session = AuthSession(
    userId: 'u1',
    sessionId: 's1',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() =>
      ensureAuthenticatedSession();

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<void> clearSession() async {}
}

class _NoopOwnershipApi extends LoadoutOwnershipApi {
  _NoopOwnershipApi({required ProgressionState progression})
    : _canonical = OwnershipCanonicalState(
        profileId: defaultOwnershipProfileId,
        revision: 0,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
        progression: progression,
      );
  final OwnershipCanonicalState _canonical;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical;
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    return _accepted();
  }

  OwnershipCommandResult _accepted() {
    return OwnershipCommandResult(
      canonicalState: _canonical,
      newRevision: _canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}
