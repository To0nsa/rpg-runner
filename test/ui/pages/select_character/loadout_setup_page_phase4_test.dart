import 'package:flutter/material.dart';
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

void main() {
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

Future<AppState> _bootstrappedAppState() async {
  final appState = AppState(
    authApi: const _StaticAuthApi(),
    loadoutOwnershipApi: _NoopOwnershipApi(),
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

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  final OwnershipCanonicalState _canonical = OwnershipCanonicalState(
    profileId: defaultOwnershipProfileId,
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial,
  );

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
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
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
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
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
