import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/achievement_progress.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

/// Shared with the TypeScript producer test, which compares these bytes with
/// real settlement/claim output. Dart must consume the same wire contract.
Map<String, dynamic> achievementFixture(String state) =>
    (jsonDecode(
          File('functions/test/fixtures/achievement_progress.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>)[state]
        as Map<String, dynamic>;

OwnershipCanonicalState achievementCanonical(
  String state, {
  int revision = 1,
  int gold = 0,
}) => OwnershipCanonicalState(
  profileId: 'main',
  revision: revision,
  selection: SelectionState.defaults,
  meta: const MetaService().createNew(),
  progression: ProgressionState(
    gold: gold,
    achievements: AchievementProgress.fromJson(achievementFixture(state)),
  ),
);

class AchievementTestAuth extends Fake implements AuthApi {
  AuthSession session = const AuthSession(
    userId: 'achievement_user',
    sessionId: 'session',
    isAnonymous: true,
    expiresAtMs: 0,
  );
  @override
  Future<AuthSession> ensureAuthenticatedSession() async => session;
  @override
  Future<AuthSession> loadSession() async => session;
  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() async => session;
  @override
  Future<void> clearSession() async {}
}

class AchievementTestApi extends Fake implements LoadoutOwnershipApi {
  AchievementTestApi(this.canonical);
  OwnershipCanonicalState canonical;
  final claims = <ClaimAchievementsCommand>[];
  Future<OwnershipCommandResult> Function(ClaimAchievementsCommand)? onClaim;
  Future<OwnershipCanonicalState> Function()? onLoad;
  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async => onLoad == null ? canonical : onLoad!();
  @override
  Future<OwnershipCommandResult> claimAchievements(
    ClaimAchievementsCommand command,
  ) async {
    claims.add(command);
    return onClaim!(command);
  }
}

OwnershipCommandResult achievementResult(
  OwnershipCanonicalState canonical, {
  OwnershipRejectedReason? rejectedReason,
}) => OwnershipCommandResult(
  canonicalState: canonical,
  newRevision: canonical.revision,
  replayedFromIdempotency: false,
  rejectedReason: rejectedReason,
);
