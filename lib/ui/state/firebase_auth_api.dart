import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_api.dart';

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

  @override
  Future<AuthSession> loadSession() async {
    final snapshot = await _source.readCurrent(forceRefresh: false);
    if (snapshot == null) {
      return AuthSession.unauthenticated;
    }
    final session = _toSession(snapshot);
    if (!session.isAuthenticatedAt(_now().millisecondsSinceEpoch)) {
      return AuthSession.unauthenticated;
    }
    return session;
  }

  @override
  Future<AuthSession> ensureAuthenticatedSession() async {
    var snapshot = await _source.readCurrent(forceRefresh: false);
    if (snapshot == null) {
      final restored = await _source.tryRestorePlayGamesSession();
      if (restored != null) {
        return _toSession(restored);
      }
      return _toSession(await _source.signInAnonymously());
    }

    final now = _now();
    if (_expiresSoon(snapshot, now)) {
      snapshot =
          await _source.readCurrent(forceRefresh: true) ??
          await _source.tryRestorePlayGamesSession() ??
          await _source.signInAnonymously();
    }

    var session = _toSession(snapshot);
    if (!session.isAuthenticatedAt(now.millisecondsSinceEpoch)) {
      snapshot =
          await _source.readCurrent(forceRefresh: true) ??
          await _source.tryRestorePlayGamesSession() ??
          await _source.signInAnonymously();
      session = _toSession(snapshot);
    }
    return session;
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

  bool _expiresSoon(FirebaseAuthSessionSnapshot snapshot, DateTime now) {
    final expiresAt = snapshot.expiresAt;
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(now.add(refreshLeeway));
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

  Future<FirebaseAuthSessionSnapshot?> tryRestorePlayGamesSession();

  Future<FirebaseAuthSessionSnapshot> signInAnonymously();

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
  Future<FirebaseAuthSessionSnapshot?> tryRestorePlayGamesSession() async {
    return _tryRestoreWithPlayGames();
  }

  @override
  Future<FirebaseAuthSessionSnapshot> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('FirebaseAuth.signInAnonymously returned null user.');
    }
    final tokenResult = await user.getIdTokenResult(true);
    return _toSnapshot(user, tokenResult);
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

    final user = await _loadCurrentOrAnonymousUser();
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

  Future<User> _loadCurrentOrAnonymousUser() async {
    var user = _auth.currentUser;
    if (user == null) {
      final anonymousCredential = await _auth.signInAnonymously();
      user = anonymousCredential.user;
    }
    if (user == null) {
      throw StateError('FirebaseAuth returned null user during provider link.');
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
