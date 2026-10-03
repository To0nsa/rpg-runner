import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_app_check_bootstrap.dart';
import '../../firebase_options.dart';
import '../state/app/app_state.dart';
import '../state/auth/firebase_auth_api.dart';
import '../state/boards/firebase_ghost_api.dart';
import '../state/boards/firebase_leaderboard_api.dart';
import '../state/boards/firebase_run_boards_api.dart';
import '../state/ownership/firebase_loadout_ownership_api.dart';
import '../state/ownership/ownership_outbox_store.dart';
import '../state/profile/firebase_account_deletion_api.dart';
import '../state/profile/firebase_user_profile_remote_api.dart';
import '../state/run/firebase_run_session_api.dart';
import 'app_services.dart';

/// Builds the standalone app's production dependencies without starting I/O.
/// Firebase and App Check must both initialize before any client is created.
AppServices createFirebaseAppServices() => AppServices(
  initialize: () async {
    // App Check can fail after Firebase succeeds; retry that stage safely.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await activateFirebaseAppCheck();
  },
  createAppState: () {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    return AppState(
      authApi: FirebaseAuthApi(),
      accountDeletionApi: FirebaseAccountDeletionApi(
        source: PluginFirebaseAccountDeletionSource(functions: functions),
      ),
      userProfileRemoteApi: FirebaseUserProfileRemoteApi(
        source: PluginFirebaseUserProfileRemoteSource(functions: functions),
      ),
      loadoutOwnershipApi: FirebaseLoadoutOwnershipApi(
        source: PluginFirebaseLoadoutOwnershipSource(functions: functions),
      ),
      ownershipOutboxStore: SharedPrefsOwnershipOutboxStore(),
      runBoardsApi: FirebaseRunBoardsApi(
        source: PluginFirebaseRunBoardsSource(functions: functions),
      ),
      runSessionApi: FirebaseRunSessionApi(
        source: PluginFirebaseRunSessionSource(functions: functions),
      ),
      leaderboardApi: FirebaseLeaderboardApi(
        source: PluginFirebaseLeaderboardSource(functions: functions),
      ),
      ghostApi: FirebaseGhostApi(
        source: PluginFirebaseGhostSource(functions: functions),
      ),
    );
  },
);
