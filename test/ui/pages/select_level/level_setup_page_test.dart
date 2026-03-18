import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/components/play_button.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/pages/selectLevel/level_setup_page.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_action_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_segmented_control_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('back navigation commits selection before returning', (
    tester,
  ) async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: ownershipApi,
      runSessionApi: const _StaticRunSessionApi(),
    );
    await appState.bootstrap(force: true);

    final initialMode = appState.selection.selectedRunMode;
    final targetMode = initialMode == RunMode.practice
        ? RunMode.competitive
        : RunMode.practice;
    final targetLabel = targetMode == RunMode.practice
        ? 'PRACTICE'
        : 'COMPETITIVE';

    await tester.pumpWidget(_BackFlowTestApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-level-setup'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(targetLabel));
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('hub-mode:${targetMode.name}'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  });

  testWidgets('disposing page flushes pending draft selection', (tester) async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: ownershipApi,
      runSessionApi: const _StaticRunSessionApi(),
    );
    await appState.bootstrap(force: true);
    final initialMode = appState.selection.selectedRunMode;
    final targetMode = initialMode == RunMode.practice
      ? RunMode.competitive
      : RunMode.practice;
    final targetLabel = targetMode == RunMode.practice
      ? 'PRACTICE'
      : 'COMPETITIVE';

    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.text(targetLabel));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(appState.selection.selectedRunMode, targetMode);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 1);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  });

  testWidgets('start run flushes pending selection before navigation', (
    tester,
  ) async {
    final ownershipApi = _RecordingOwnershipApi();
    final appState = AppState(
      authApi: const _StaticAuthApi(),
      loadoutOwnershipApi: ownershipApi,
      runSessionApi: const _StaticRunSessionApi(),
    );
    await appState.bootstrap(force: true);
    await appState.setCharacter(PlayerCharacterId.eloiseWip);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 1);

    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PlayButton));
    await tester.pumpAndSettle();

    expect(find.text('run-bootstrap-route-marker'), findsOneWidget);
    expect(ownershipApi.setSelectionCalls, 1);
    expect(appState.ownershipSyncStatus.pendingSelectionCount, 0);
  });
}

class _BackFlowTestApp extends StatelessWidget {
  const _BackFlowTestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<UiAssetLifecycle>(create: (_) => UiAssetLifecycle()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: <ThemeExtension<dynamic>>[
            UiTokens.standard,
            UiButtonTheme.standard,
            UiActionButtonTheme.standard,
            UiSegmentedControlTheme.standard,
          ],
        ),
        home: Builder(
          builder: (context) {
            final state = context.watch<AppState>();
            return Scaffold(
              body: Column(
                children: [
                  Text('hub-mode:${state.selection.selectedRunMode.name}'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LevelSetupPage(),
                        ),
                      );
                    },
                    child: const Text('open-level-setup'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<UiAssetLifecycle>(create: (_) => UiAssetLifecycle()),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: <ThemeExtension<dynamic>>[
            UiTokens.standard,
            UiButtonTheme.standard,
            UiActionButtonTheme.standard,
            UiSegmentedControlTheme.standard,
          ],
        ),
        home: const LevelSetupPage(),
        routes: <String, WidgetBuilder>{
          UiRoutes.runBootstrap: (_) =>
              const Scaffold(body: Text('run-bootstrap-route-marker')),
          UiRoutes.run: (_) => const Scaffold(body: Text('run-route-marker')),
        },
      ),
    );
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

class _RecordingOwnershipApi implements LoadoutOwnershipApi {
  int _revision = 0;
  int setSelectionCalls = 0;
  SelectionState _selection = SelectionState.defaults;
  final MetaService _metaService = const MetaService();

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
      revision: _revision,
      selection: _selection,
      meta: _metaService.createNew(),
      progression: ProgressionState.initial,
    );
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    setSelectionCalls += 1;
    _selection = command.selection;
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async =>
      _accepted();

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async =>
      _accepted();

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async =>
      _accepted();

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async => _accepted();

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async => _accepted();

  OwnershipCommandResult _accepted() {
    _revision += 1;
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}

class _StaticRunSessionApi implements RunSessionApi {
  const _StaticRunSessionApi();

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    return RunTicket(
      runSessionId: 'run_1',
      uid: userId,
      mode: mode,
      seed: 5,
      tickHz: 60,
      gameCompatVersion: gameCompatVersion,
      levelId: levelId.name,
      playerCharacterId: 'eloise',
      loadoutSnapshot: const <String, Object?>{},
      loadoutDigest: 'digest',
      issuedAtMs: 1,
      expiresAtMs: 999999999999,
      singleUseNonce: 'nonce',
    );
  }

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw UnimplementedError();
  }
}
