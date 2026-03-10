import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';

class LocalAuthApi implements AuthApi {
  LocalAuthApi({
    Random? random,
    DateTime Function()? now,
    this.sessionTtl = const Duration(hours: 12),
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  static const String _prefsKey = 'ui.auth_session.v1';

  final Random _random;
  final DateTime Function() _now;
  final Duration sessionTtl;

  @override
  Future<AuthSession> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return AuthSession.unauthenticated;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AuthSession.fromJson(
          decoded,
          fallback: AuthSession.unauthenticated,
        );
      }
      if (decoded is Map) {
        return AuthSession.fromJson(
          Map<String, dynamic>.from(decoded),
          fallback: AuthSession.unauthenticated,
        );
      }
    } catch (_) {
      // Fall through to unauthenticated.
    }
    return AuthSession.unauthenticated;
  }

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    final nowMs = _now().millisecondsSinceEpoch;
    final current = await loadSession();
    if (current.isAuthenticatedAt(nowMs)) {
      return current;
    }
    final created = _createAnonymousSession(nowMs);
    await _saveSession(created);
    return created;
  }

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final session = await ensureAuthenticatedSession();
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
      sessionId: _createSessionId(nowMs),
      expiresAtMs: nowMs + sessionTtl.inMilliseconds,
    );
    await _saveSession(upgraded);
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.linked,
      session: upgraded,
    );
  }

  @override
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(session.toJson()));
  }

  AuthSession _createAnonymousSession(int nowMs) {
    final userId = 'anon_${_random.nextInt(1 << 31).toRadixString(36)}';
    final sessionId = _createSessionId(nowMs);
    return AuthSession(
      userId: userId,
      sessionId: sessionId,
      isAnonymous: true,
      expiresAtMs: nowMs + sessionTtl.inMilliseconds,
    );
  }

  String _createSessionId(int nowMs) {
    final sessionId =
        'sess_${nowMs.toRadixString(36)}_${_random.nextInt(1 << 31).toRadixString(36)}';
    return sessionId;
  }
}
