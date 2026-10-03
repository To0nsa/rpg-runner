import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/app/app_services.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/state/profile/user_profile.dart';
import 'package:rpg_runner/ui/state/profile/user_profile_remote_api.dart';

class StartupFixture {
  final auth = StartupAuthApi();
  final profile = StartupProfileApi();
  final ownership = StartupOwnershipApi();
  Object? initializationError;
  Completer<void>? initializationGate;
  int initializationCalls = 0;
  int stateCreations = 0;
  late final services = AppServices(
    initialize: () async {
      initializationCalls++;
      await initializationGate?.future;
      if (initializationError case final error?) throw error;
    },
    createAppState: () {
      stateCreations++;
      return AppState(
        authApi: auth,
        userProfileRemoteApi: profile,
        loadoutOwnershipApi: ownership,
      );
    },
  );
}

class StartupAuthApi extends Fake implements AuthApi {
  int calls = 0;
  Object? error;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    calls++;
    if (error case final failure?) throw failure;
    return const AuthSession(
      userId: 'startup_player',
      sessionId: 'startup_session',
      isAnonymous: false,
      expiresAtMs: 0,
      linkedProviders: {AuthLinkProvider.playGames},
    );
  }
}

class StartupProfileApi extends Fake implements UserProfileRemoteApi {
  UserProfile profile = UserProfile.empty;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<UserProfile> loadProfile({
    required String userId,
    required String sessionId,
  }) async {
    calls++;
    await gate?.future;
    if (error case final failure?) throw failure;
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String sessionId,
    required UserProfileUpdate update,
  }) async => profile = profile.copyWith(
    displayName: update.displayName,
    namePromptCompleted: update.namePromptCompleted,
  );
}

class StartupOwnershipApi extends Fake implements LoadoutOwnershipApi {
  int calls = 0;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    calls++;
    return OwnershipCanonicalState(
      profileId: defaultOwnershipProfileId,
      revision: 0,
      selection: SelectionState.defaults,
      meta: const MetaService().createNew(),
      progression: ProgressionState.initial,
    );
  }
}
