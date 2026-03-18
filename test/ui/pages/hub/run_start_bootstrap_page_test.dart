import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/pages/hub/run_start_bootstrap_page.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/run_session_api.dart';
import 'package:rpg_runner/ui/state/run_start_remote_exception.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  testWidgets('bootstrap page replaces itself with run route on success', (
    tester,
  ) async {
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: _SuccessRunSessionApi(),
    );
    await appState.bootstrap(force: true);

    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pumpAndSettle();

    expect(find.text('Run Route Placeholder'), findsOneWidget);
  });

  testWidgets('bootstrap page shows retry on run-start failure', (tester) async {
    final runSessionApi = _ThrowingRunSessionApi();
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _NoopOwnershipApi(),
      runSessionApi: runSessionApi,
    );
    await appState.bootstrap(force: true);

    await tester.pumpWidget(_TestApp(appState: appState));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to start run right now. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(runSessionApi.createRunSessionCalls, greaterThanOrEqualTo(2));
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<UiAssetLifecycle>(create: (_) => _NoopUiAssetLifecycle()),
      ],
      child: MaterialApp(
        initialRoute: UiRoutes.runBootstrap,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case UiRoutes.runBootstrap:
              final args = settings.arguments;
              final bootstrapArgs = args is RunStartBootstrapArgs
                  ? args
                  : const RunStartBootstrapArgs();
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => RunStartBootstrapPage(args: bootstrapArgs),
              );
            case UiRoutes.run:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Run Route Placeholder')),
                ),
              );
            default:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
          }
        },
      ),
    );
  }
}

class _NoopUiAssetLifecycle extends UiAssetLifecycle {
  _NoopUiAssetLifecycle();

  @override
  Future<void> warmRunStartAssets({
    required LevelId levelId,
    required PlayerCharacterId characterId,
    required BuildContext context,
  }) async {}
}

class _SuccessRunSessionApi implements RunSessionApi {
  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return RunTicket(
      runSessionId: 'run_session_success',
      uid: userId,
      mode: mode,
      seed: 12345,
      tickHz: 60,
      gameCompatVersion: gameCompatVersion,
      levelId: levelId.name,
      playerCharacterId: PlayerCharacterId.eloise.name,
      loadoutSnapshot: const <String, Object?>{
        'mask': 255,
        'mainWeaponId': 'plainsteel',
        'offhandWeaponId': 'roadguard',
        'spellBookId': 'apprenticePrimer',
        'projectileSlotSpellId': 'iceBolt',
        'accessoryId': 'strengthBelt',
        'abilityPrimaryId': 'eloise.seeker_slash',
        'abilitySecondaryId': 'eloise.shield_block',
        'abilityProjectileId': 'eloise.snap_shot',
        'abilitySpellId': 'eloise.arcane_haste',
        'abilityMobilityId': 'eloise.dash',
        'abilityJumpId': 'eloise.jump',
      },
      loadoutDigest:
          '0123456789012345678901234567890123456789012345678901234567890123',
      issuedAtMs: nowMs,
      expiresAtMs: nowMs + 60000,
      singleUseNonce: 'nonce_1',
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

class _ThrowingRunSessionApi implements RunSessionApi {
  int createRunSessionCalls = 0;

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) async {
    createRunSessionCalls += 1;
    throw const RunStartRemoteException(
      code: 'unavailable',
      message: 'network unavailable',
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

class _NoopOwnershipApi implements LoadoutOwnershipApi {
  int _revision = 0;
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

  OwnershipCommandResult _accepted() {
    _revision += 1;
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
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
  Future<OwnershipCommandResult> setSelection(SetSelectionCommand command) async {
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
}

class _StaticAuthApi implements AuthApi {
  _StaticAuthApi.authenticated()
    : _session = AuthSession(
        userId: 'user_1',
        sessionId: 'session_1',
        isAnonymous: false,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
      );

  final AuthSession _session;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<void> clearSession() async {}

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.unsupported,
      session: _session,
    );
  }

  @override
  Future<AuthSession> loadSession() async => _session;
}
