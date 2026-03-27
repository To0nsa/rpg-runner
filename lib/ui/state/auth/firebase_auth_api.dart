import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_api.dart';

/// Thrown when strict Play Games authentication cannot be established.
class PlayGamesAuthRequiredException implements Exception {
  const PlayGamesAuthRequiredException([
    this.message = 'Play Games sign-in is required to continue.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Firebase-backed [AuthApi] adapter used by production UI composition.
class FirebaseAuthApi implements AuthApi {
  FirebaseAuthApi({
    FirebaseAuthSessionSource? source,
    DateTime Function()? now,
    this.refreshLeeway = const Duration(minutes: 1),
  }) : _source =
           source ?? PluginFirebaseAuthSessionSource(FirebaseAuth.instance),
       _now = now ?? DateTime.now;

  final FirebaseAuthSessionSource _source;
  final DateTime Function() _now;
  final Duration refreshLeeway;
  Future<AuthSession>? _ensureSessionInFlight;

  @override
  Future<AuthSession> loadSession() async {
    final snapshot = await _readCurrentWithCachedFallback(forceRefresh: false);
    if (snapshot == null) {
      return AuthSession.unauthenticated;
    }
    final session = _toSession(snapshot);
    if (!_sessionSatisfiesPlayGamesAuth(
      session,
      nowMs: _now().millisecondsSinceEpoch,
    )) {
      return AuthSession.unauthenticated;
    }
    return session;
  }

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    final inFlight = _ensureSessionInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final operation = _ensureAuthenticatedSessionInternal();
    _ensureSessionInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_ensureSessionInFlight, operation)) {
        _ensureSessionInFlight = null;
      }
    }
  }

  Future<AuthSession> _ensureAuthenticatedSessionInternal() async {
    final now = _now();
    final nowMs = now.millisecondsSinceEpoch;
    var snapshot = await _readCurrentWithCachedFallback(forceRefresh: false);
    if (snapshot == null || !_snapshotHasPlayGamesIdentity(snapshot)) {
      snapshot = await _restoreRequiredPlayGamesSnapshot();
    }

    if (_expiresSoon(snapshot, now)) {
      final refreshed = await _readCurrentWithCachedFallback(
        forceRefresh: true,
      );
      if (refreshed != null && _snapshotHasPlayGamesIdentity(refreshed)) {
        snapshot = refreshed;
      } else {
        snapshot = await _restoreRequiredPlayGamesSnapshot();
      }
    }

    var session = _toSession(snapshot);
    if (!_sessionSatisfiesPlayGamesAuth(session, nowMs: nowMs)) {
      final refreshed = await _readCurrentWithCachedFallback(
        forceRefresh: true,
      );
      if (refreshed != null &&
          _snapshotSatisfiesPlayGamesAuth(refreshed, nowMs: nowMs)) {
        session = _toSession(refreshed);
      } else {
        session = _toSession(await _restoreRequiredPlayGamesSnapshot());
      }
    }
    if (!_sessionSatisfiesPlayGamesAuth(
      session,
      nowMs: _now().millisecondsSinceEpoch,
    )) {
      throw const PlayGamesAuthRequiredException();
    }
    return session;
  }

  Future<FirebaseAuthSessionSnapshot>
  _restoreRequiredPlayGamesSnapshot() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const PlayGamesAuthRequiredException(
        'Play Games sign-in is supported on Android only.',
      );
    }
    final restored = await _source.tryRestorePlayGamesSession();
    final nowMs = _now().millisecondsSinceEpoch;
    if (restored != null &&
        _snapshotSatisfiesPlayGamesAuth(restored, nowMs: nowMs)) {
      return restored;
    }
    final cachedCurrent = await _source.readCachedCurrent();
    if (cachedCurrent != null &&
        _snapshotSatisfiesPlayGamesAuth(cachedCurrent, nowMs: nowMs)) {
      return cachedCurrent;
    }
    throw const PlayGamesAuthRequiredException();
  }

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    final current = await ensureAuthenticatedSession();
    if (current.isProviderLinked(provider)) {
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.alreadyLinked,
        session: current,
      );
    }

    try {
      final linkedSnapshot = await _source.linkAuthProvider(provider);
      if (linkedSnapshot == null) {
        return AuthLinkResult(
          provider: provider,
          status: AuthLinkStatus.canceled,
          session: current,
        );
      }
      final linkedSession = _toSession(linkedSnapshot);
      if (!linkedSession.isProviderLinked(provider)) {
        return AuthLinkResult(
          provider: provider,
          status: AuthLinkStatus.failed,
          session: linkedSession,
          errorCode: 'provider-not-linked',
          errorMessage:
              'Provider link flow completed without linking the requested provider.',
        );
      }
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.linked,
        session: linkedSession,
      );
    } on UnsupportedError catch (error) {
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.unsupported,
        session: await _resolveSessionFallback(current),
        errorCode: 'provider-unsupported',
        errorMessage: '${error.message}',
      );
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'FirebaseAuth link failed for ${provider.name}: '
        'code=${error.code} message=${error.message ?? "<null>"}',
      );
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.failed,
        session: await _resolveSessionFallback(current),
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on PlatformException catch (error) {
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.failed,
        session: await _resolveSessionFallback(current),
        errorCode: error.code,
        errorMessage: error.message,
      );
    } catch (error) {
      debugPrint('Auth link failed for ${provider.name}: $error');
      return AuthLinkResult(
        provider: provider,
        status: AuthLinkStatus.failed,
        session: await _resolveSessionFallback(current),
        errorCode: 'link-failed',
        errorMessage: '$error',
      );
    }
  }

  @override
  Future<void> clearSession() async {
    await _source.signOut();
  }

  Future<AuthSession> _resolveSessionFallback(AuthSession fallback) async {
    try {
      final active = await loadSession();
      if (active.isAuthenticated) {
        return active;
      }
    } catch (_) {
      // Keep fallback.
    }
    return fallback;
  }

  Future<FirebaseAuthSessionSnapshot?> _readCurrentWithCachedFallback({
    required bool forceRefresh,
  }) async {
    try {
      return await _source.readCurrent(forceRefresh: forceRefresh);
    } on FirebaseAuthException catch (error) {
      final fallback = await _cachedFallbackForNetworkError(
        code: error.code,
        message: error.message,
      );
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    } on PlatformException catch (error) {
      final fallback = await _cachedFallbackForNetworkError(
        code: error.code,
        message: error.message,
      );
      if (fallback != null) {
        return fallback;
      }
      rethrow;
    }
  }

  Future<FirebaseAuthSessionSnapshot?> _cachedFallbackForNetworkError({
    required String code,
    required String? message,
  }) async {
    if (!_isNetworkRequestFailure(code: code, message: message)) {
      return null;
    }
    return _source.readCachedCurrent();
  }

  bool _isNetworkRequestFailure({
    required String code,
    required String? message,
  }) {
    if (code == 'network-request-failed') {
      return true;
    }
    final normalized = message?.toLowerCase() ?? '';
    return normalized.contains('network error') ||
        normalized.contains('timeout') ||
        normalized.contains('unreachable host') ||
        normalized.contains('interrupted connection');
  }

  bool _expiresSoon(FirebaseAuthSessionSnapshot snapshot, DateTime now) {
    final expiresAt = snapshot.expiresAt;
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(now.add(refreshLeeway));
  }

  bool _snapshotSatisfiesPlayGamesAuth(
    FirebaseAuthSessionSnapshot snapshot, {
    required int nowMs,
  }) {
    final session = _toSession(snapshot);
    return _sessionSatisfiesPlayGamesAuth(session, nowMs: nowMs);
  }

  bool _snapshotHasPlayGamesIdentity(FirebaseAuthSessionSnapshot snapshot) {
    return _sessionHasPlayGamesIdentity(_toSession(snapshot));
  }

  bool _sessionSatisfiesPlayGamesAuth(
    AuthSession session, {
    required int nowMs,
  }) {
    return _sessionHasPlayGamesIdentity(session) &&
        session.isAuthenticatedAt(nowMs);
  }

  bool _sessionHasPlayGamesIdentity(AuthSession session) {
    return !session.isAnonymous &&
        session.isProviderLinked(AuthLinkProvider.playGames);
  }

  AuthSession _toSession(FirebaseAuthSessionSnapshot snapshot) {
    return AuthSession(
      userId: snapshot.userId,
      sessionId: _buildSessionId(snapshot),
      isAnonymous: snapshot.isAnonymous,
      expiresAtMs: snapshot.expiresAt?.millisecondsSinceEpoch ?? 0,
      linkedProviders: snapshot.linkedProviders,
    );
  }

  String _buildSessionId(FirebaseAuthSessionSnapshot snapshot) {
    final issuedAtMs = snapshot.issuedAt?.millisecondsSinceEpoch ?? 0;
    final expiresAtMs = snapshot.expiresAt?.millisecondsSinceEpoch ?? 0;
    final material =
        snapshot.idToken ??
        '${snapshot.userId}|${snapshot.refreshToken ?? ''}|$issuedAtMs|$expiresAtMs';
    final fingerprint = _fnv1a32Hex(material);
    return 'fb_${snapshot.userId}_${issuedAtMs.toRadixString(36)}_$fingerprint';
  }

  String _fnv1a32Hex(String input) {
    const int offsetBasis = 0x811C9DC5;
    const int prime = 0x01000193;
    var hash = offsetBasis;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

/// Firebase user/token snapshot required to derive [AuthSession].
class FirebaseAuthSessionSnapshot {
  const FirebaseAuthSessionSnapshot({
    required this.userId,
    required this.isAnonymous,
    this.idToken,
    this.refreshToken,
    this.issuedAt,
    this.expiresAt,
    this.linkedProviders = const <AuthLinkProvider>{},
  });

  final String userId;
  final bool isAnonymous;
  final String? idToken;
  final String? refreshToken;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final Set<AuthLinkProvider> linkedProviders;
}

/// Retrieves a Play Games server auth code on Android.
abstract class PlayGamesServerAuthCodeSource {
  Future<String?> requestServerAuthCode();
}

/// Android bridge for Play Games v2 server-side auth access.
class MethodChannelPlayGamesServerAuthCodeSource
    implements PlayGamesServerAuthCodeSource {
  const MethodChannelPlayGamesServerAuthCodeSource();

  static const MethodChannel _channel = MethodChannel(
    'rpg_runner/play_games_auth',
  );

  @override
  Future<String?> requestServerAuthCode() async {
    try {
      return await _channel.invokeMethod<String>('requestServerAuthCode');
    } on PlatformException catch (error) {
      if (_isCanceled(error)) {
        return null;
      }
      rethrow;
    }
  }

  bool _isCanceled(PlatformException error) {
    return error.code == 'canceled' || error.code == 'sign_in_canceled';
  }
}

/// Abstraction for Firebase auth reads/writes so auth lifecycle can be tested.
abstract class FirebaseAuthSessionSource {
  Future<FirebaseAuthSessionSnapshot?> readCurrent({
    required bool forceRefresh,
  });

  Future<FirebaseAuthSessionSnapshot?> readCachedCurrent();

  Future<FirebaseAuthSessionSnapshot?> tryRestorePlayGamesSession();

  Future<FirebaseAuthSessionSnapshot?> linkAuthProvider(
    AuthLinkProvider provider,
  );

  Future<void> signOut();
}

/// Production session source backed by `package:firebase_auth`.
class PluginFirebaseAuthSessionSource implements FirebaseAuthSessionSource {
  PluginFirebaseAuthSessionSource(
    this._auth, {
    PlayGamesServerAuthCodeSource? playGamesAuthCodeSource,
  }) : _playGamesAuthCodeSource =
           playGamesAuthCodeSource ??
           const MethodChannelPlayGamesServerAuthCodeSource();

  final FirebaseAuth _auth;
  final PlayGamesServerAuthCodeSource _playGamesAuthCodeSource;

  @override
  Future<FirebaseAuthSessionSnapshot?> readCurrent({
    required bool forceRefresh,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    final tokenResult = await user.getIdTokenResult(forceRefresh);
    return _toSnapshot(user, tokenResult);
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> readCachedCurrent() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return FirebaseAuthSessionSnapshot(
      userId: user.uid,
      isAnonymous: user.isAnonymous,
      refreshToken: user.refreshToken,
      linkedProviders: _extractLinkedProviders(user),
    );
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> tryRestorePlayGamesSession() async {
    return _tryRestoreWithPlayGames();
  }

  @override
  Future<FirebaseAuthSessionSnapshot?> linkAuthProvider(
    AuthLinkProvider provider,
  ) async {
    switch (provider) {
      case AuthLinkProvider.playGames:
        return _linkWithPlayGames();
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<FirebaseAuthSessionSnapshot?> _linkWithPlayGames() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'Play Games sign-in is supported on Android only.',
      );
    }

    final user = _loadCurrentUserForProviderLink();
    if (_isProviderLinked(user, AuthLinkProvider.playGames)) {
      final tokenResult = await user.getIdTokenResult(true);
      return _toSnapshot(user, tokenResult);
    }

    final serverAuthCode = await _playGamesAuthCodeSource
        .requestServerAuthCode();
    if (serverAuthCode == null) {
      return null;
    }

    if (serverAuthCode.isEmpty) {
      throw StateError(
        'Play Games sign-in did not return a server auth code. '
        'Verify Play Games OAuth client ID/secret setup in Firebase.',
      );
    }

    final credential = PlayGamesAuthProvider.credential(
      serverAuthCode: serverAuthCode,
    );
    final linkedUser = await _linkUserWithCredential(
      user: user,
      provider: AuthLinkProvider.playGames,
      credential: credential,
    );
    final tokenResult = await linkedUser.getIdTokenResult(true);
    return _toSnapshot(linkedUser, tokenResult);
  }

  Future<FirebaseAuthSessionSnapshot?> _tryRestoreWithPlayGames() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final serverAuthCode = await _playGamesAuthCodeSource
          .requestServerAuthCode();
      if (serverAuthCode == null || serverAuthCode.isEmpty) {
        return null;
      }
      final credential = PlayGamesAuthProvider.credential(
        serverAuthCode: serverAuthCode,
      );
      final restored = await _auth.signInWithCredential(credential);
      final user = restored.user;
      if (user == null) {
        throw StateError(
          'FirebaseAuth.signInWithCredential returned null user during Play Games restore.',
        );
      }
      final tokenResult = await user.getIdTokenResult(true);
      return _toSnapshot(user, tokenResult);
    } on PlatformException catch (error) {
      debugPrint('Play Games restore failed: ${error.code} ${error.message}');
      return null;
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Play Games restore FirebaseAuthException: ${error.code} ${error.message}',
      );
      return null;
    } catch (error) {
      debugPrint('Play Games restore failed: $error');
      return null;
    }
  }

  FirebaseAuthSessionSnapshot _toSnapshot(User user, IdTokenResult token) {
    return FirebaseAuthSessionSnapshot(
      userId: user.uid,
      isAnonymous: user.isAnonymous,
      idToken: token.token,
      refreshToken: user.refreshToken,
      issuedAt: token.issuedAtTime,
      expiresAt: token.expirationTime,
      linkedProviders: _extractLinkedProviders(user),
    );
  }

  User _loadCurrentUserForProviderLink() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const PlayGamesAuthRequiredException(
        'Play Games sign-in is required before linking providers.',
      );
    }
    return user;
  }

  Future<User> _linkUserWithCredential({
    required User user,
    required AuthLinkProvider provider,
    required AuthCredential credential,
  }) async {
    try {
      final linkedCredential = await user.linkWithCredential(credential);
      final linkedUser = linkedCredential.user;
      if (linkedUser == null) {
        throw StateError('FirebaseAuth.linkWithCredential returned null user.');
      }
      return linkedUser;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        final refreshed = _auth.currentUser ?? user;
        if (_isProviderLinked(refreshed, provider)) {
          return refreshed;
        }
      }
      rethrow;
    }
  }

  bool _isProviderLinked(User user, AuthLinkProvider provider) {
    return _extractLinkedProviders(user).contains(provider);
  }

  Set<AuthLinkProvider> _extractLinkedProviders(User user) {
    final providers = <AuthLinkProvider>{};
    for (final providerInfo in user.providerData) {
      final linkedProvider = _providerFromId(providerInfo.providerId);
      if (linkedProvider != null) {
        providers.add(linkedProvider);
      }
    }
    return providers;
  }

  AuthLinkProvider? _providerFromId(String providerId) {
    return switch (providerId) {
      _playGamesProviderId => AuthLinkProvider.playGames,
      _ => null,
    };
  }

  static const String _playGamesProviderId = 'playgames.google.com';
}
