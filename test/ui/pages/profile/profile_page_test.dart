import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/pages/profile/profile_page.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets('shows manage linked accounts for anonymous session', (
    tester,
  ) async {
    final authApi = _FakeAuthApi(session: _anonymousSession());
    final appState = AppState(authApi: authApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    expect(find.text('Manage linked accounts'), findsOneWidget);
    expect(find.text('Link Google'), findsOneWidget);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      expect(find.text('Link Play Games'), findsOneWidget);
    } else {
      expect(find.text('Link Play Games'), findsNothing);
    }
    expect(find.text('Guest (Anonymous)'), findsOneWidget);
  });

  testWidgets('Link Google button triggers provider link and feedback', (
    tester,
  ) async {
    final authApi = _FakeAuthApi(session: _anonymousSession());
    final appState = AppState(authApi: authApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Link Google'));
    await tester.pumpAndSettle();

    expect(authApi.upgradeCalls, 1);
    expect(authApi.lastProvider, AuthLinkProvider.google);
    expect(find.text('Google account linked.'), findsOneWidget);
    expect(
      appState.authSession.isProviderLinked(AuthLinkProvider.google),
      isTrue,
    );
    expect(find.text('Registered (1 linked)'), findsOneWidget);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      expect(find.text('Link Play Games'), findsOneWidget);
    }
  });

  testWidgets('Link Play Games button triggers provider link and feedback', (
    tester,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final authApi = _FakeAuthApi(session: _anonymousSession());
    final appState = AppState(authApi: authApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Link Play Games'));
    await tester.pumpAndSettle();

    expect(authApi.upgradeCalls, 1);
    expect(authApi.lastProvider, AuthLinkProvider.playGames);
    expect(find.text('Play Games account linked.'), findsOneWidget);
    expect(
      appState.authSession.isProviderLinked(AuthLinkProvider.playGames),
      isTrue,
    );
    expect(find.text('Registered (1 linked)'), findsOneWidget);
    expect(find.text('Link Google'), findsOneWidget);
  });

  testWidgets('shows linked Google state and keeps other provider action', (
    tester,
  ) async {
    final authApi = _FakeAuthApi(session: _linkedGoogleSession());
    final appState = AppState(authApi: authApi);
    await appState.linkAuthProvider(AuthLinkProvider.google);

    await tester.pumpWidget(_TestApp(appState: appState));

    expect(find.text('Link Google'), findsNothing);
    expect(find.text('Registered (1 linked)'), findsOneWidget);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      expect(find.text('Link Play Games'), findsOneWidget);
    }
  });
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
          extensions: [UiTokens.standard, UiButtonTheme.standard],
        ),
        home: const ProfilePage(),
      ),
    );
  }
}

class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({required this.session});

  AuthSession session;
  int upgradeCalls = 0;
  AuthLinkProvider? lastProvider;

  @override
  Future<AuthSession> loadSession() async => session;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    upgradeCalls += 1;
    lastProvider = provider;
    if (session.isProviderLinked(provider)) {
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.alreadyLinked,
        session: session,
      );
    }
    final nextProviders = <AuthLinkProvider>{
      ...session.linkedProviders,
      provider,
    };
    final upgraded = session.copyWith(
      isAnonymous: false,
      linkedProviders: nextProviders,
      sessionId: 'linked_${session.sessionId}',
    );
    session = upgraded;
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.linked,
      session: upgraded,
    );
  }

  @override
  Future<void> clearSession() async {
    session = AuthSession.unauthenticated;
  }
}

AuthSession _anonymousSession() {
  return const AuthSession(
    userId: 'anon_u1',
    sessionId: 'sess_anon',
    isAnonymous: true,
    expiresAtMs: 0,
  );
}

AuthSession _linkedGoogleSession() {
  return const AuthSession(
    userId: 'u1',
    sessionId: 'sess_linked',
    isAnonymous: false,
    expiresAtMs: 0,
    linkedProviders: <AuthLinkProvider>{AuthLinkProvider.google},
  );
}
