enum AuthLinkProvider { google, playGames }

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.sessionId,
    required this.isAnonymous,
    required this.expiresAtMs,
    this.linkedProviders = const <AuthLinkProvider>{},
  });

  static const AuthSession unauthenticated = AuthSession(
    userId: '',
    sessionId: '',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  final String userId;
  final String sessionId;
  final bool isAnonymous;
  final int expiresAtMs;
  final Set<AuthLinkProvider> linkedProviders;

  bool get isAuthenticated {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return isAuthenticatedAt(nowMs);
  }

  bool isAuthenticatedAt(int nowMs) {
    if (userId.isEmpty || sessionId.isEmpty) return false;
    if (expiresAtMs <= 0) return true;
    return nowMs < expiresAtMs;
  }

  bool isProviderLinked(AuthLinkProvider provider) {
    return linkedProviders.contains(provider);
  }

  AuthSession copyWith({
    String? userId,
    String? sessionId,
    bool? isAnonymous,
    int? expiresAtMs,
    Set<AuthLinkProvider>? linkedProviders,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      linkedProviders: linkedProviders ?? this.linkedProviders,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
      'isAnonymous': isAnonymous,
      'expiresAtMs': expiresAtMs,
      'linkedProviders': linkedProviders.map(_encodeAuthLinkProvider).toList()
        ..sort(),
    };
  }

  static AuthSession fromJson(
    Map<String, dynamic> json, {
    required AuthSession fallback,
  }) {
    final userIdRaw = json['userId'];
    final sessionIdRaw = json['sessionId'];
    final isAnonymousRaw = json['isAnonymous'];
    final expiresAtMsRaw = json['expiresAtMs'];
    return AuthSession(
      userId: userIdRaw is String ? userIdRaw : fallback.userId,
      sessionId: sessionIdRaw is String ? sessionIdRaw : fallback.sessionId,
      isAnonymous: isAnonymousRaw is bool
          ? isAnonymousRaw
          : fallback.isAnonymous,
      expiresAtMs: expiresAtMsRaw is int
          ? expiresAtMsRaw
          : (expiresAtMsRaw is num
                ? expiresAtMsRaw.toInt()
                : fallback.expiresAtMs),
      linkedProviders: _decodeAuthLinkProviders(
        json['linkedProviders'],
        fallback: fallback.linkedProviders,
      ),
    );
  }
}

enum AuthLinkStatus { linked, alreadyLinked, canceled, failed, unsupported }

class AuthLinkResult {
  const AuthLinkResult({
    required this.provider,
    required this.status,
    required this.session,
    this.errorCode,
    this.errorMessage,
  });

  final AuthLinkProvider provider;
  final AuthLinkStatus status;
  final AuthSession session;
  final String? errorCode;
  final String? errorMessage;

  bool get succeeded =>
      status == AuthLinkStatus.linked || status == AuthLinkStatus.alreadyLinked;
}

abstract class AuthApi {
  Future<AuthSession> loadSession();

  Future<AuthSession> ensureAuthenticatedSession();

  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider);

  Future<void> clearSession();
}

String _encodeAuthLinkProvider(AuthLinkProvider provider) {
  return switch (provider) {
    AuthLinkProvider.google => 'google',
    AuthLinkProvider.playGames => 'playGames',
  };
}

Set<AuthLinkProvider> _decodeAuthLinkProviders(
  Object? raw, {
  required Set<AuthLinkProvider> fallback,
}) {
  if (raw is! List) {
    return fallback;
  }
  final parsed = <AuthLinkProvider>{};
  for (final value in raw) {
    if (value is! String) continue;
    final provider = switch (value) {
      'google' => AuthLinkProvider.google,
      'playGames' => AuthLinkProvider.playGames,
      _ => null,
    };
    if (provider != null) {
      parsed.add(provider);
    }
  }
  return parsed;
}
