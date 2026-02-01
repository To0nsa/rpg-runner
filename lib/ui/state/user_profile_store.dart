import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';
import 'profile_counter_keys.dart';

class UserProfileStore {
  UserProfileStore({Random? random, DateTime Function()? now})
      : _random = random ?? Random(),
        _now = now ?? DateTime.now;

  static const String _prefsKey = 'ui.user_profile';

  final Random _random;
  final DateTime Function() _now;

  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final nowMs = _now().millisecondsSinceEpoch;
    final fallbackProfileId = _generateProfileId(nowMs);

    if (raw == null || raw.isEmpty) {
      final created = UserProfile.createNew(
        profileId: fallbackProfileId,
        nowMs: nowMs,
      );
      await save(created);
      return created;
    }

    try {
      final decoded = jsonDecode(raw);
      Map<String, dynamic>? map;
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }

      if (map == null) {
        _logWarning(
          'Expected map payload for user profile but found '
          '${decoded.runtimeType}.',
        );
      } else {
        final migration = _migrateToLatest(
          map,
          nowMs: nowMs,
          fallbackProfileId: fallbackProfileId,
        );
        final profile = UserProfile.fromJson(
          migration.data,
          fallbackProfileId: fallbackProfileId,
          nowMs: nowMs,
        );
        if (migration.didChange) {
          await save(profile);
        }
        return profile;
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to decode stored user profile.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final created = UserProfile.createNew(
      profileId: fallbackProfileId,
      nowMs: nowMs,
    );
    await save(created);
    return created;
  }

  Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(profile.toJson());
    await prefs.setString(_prefsKey, payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  UserProfile createFresh() {
    final nowMs = _now().millisecondsSinceEpoch;
    return UserProfile.createNew(
      profileId: _generateProfileId(nowMs),
      nowMs: nowMs,
    );
  }

  _MigrationResult _migrateToLatest(
    Map<String, dynamic> raw, {
    required int nowMs,
    required String fallbackProfileId,
  }) {
    var didChange = false;
    final data = Map<String, dynamic>.from(raw);

    final schemaVersion = _readInt(data['schemaVersion']);
    if (schemaVersion == null) {
      data['schemaVersion'] = UserProfile.latestSchemaVersion;
      didChange = true;
    } else if (schemaVersion < UserProfile.latestSchemaVersion) {
      data['schemaVersion'] = UserProfile.latestSchemaVersion;
      didChange = true;
    }

    final profileId = data['profileId'];
    if (profileId is! String || profileId.isEmpty) {
      data['profileId'] = fallbackProfileId;
      didChange = true;
    }

    final createdAtMs = _readInt(data['createdAtMs']);
    if (createdAtMs == null) {
      data['createdAtMs'] = nowMs;
      didChange = true;
    }

    final updatedAtMs = _readInt(data['updatedAtMs']);
    if (updatedAtMs == null) {
      data['updatedAtMs'] = createdAtMs ?? nowMs;
      didChange = true;
    }

    final revision = _readInt(data['revision']);
    if (revision == null) {
      data['revision'] = 0;
      didChange = true;
    }

    if (data['flags'] is! Map) {
      data['flags'] = <String, bool>{};
      didChange = true;
    }

    if (data['counters'] is! Map) {
      data['counters'] = <String, int>{};
      didChange = true;
    } else {
      final counters = data['counters'];
      if (counters is Map && !counters.containsKey(ProfileCounterKeys.gold)) {
        counters[ProfileCounterKeys.gold] = 0;
        didChange = true;
      }
    }

    return _MigrationResult(data, didChange);
  }

  String _generateProfileId(int nowMs) {
    final stamp = nowMs.toRadixString(36);
    final suffix = _random.nextInt(1 << 31).toRadixString(36);
    return 'guest_${stamp}_$suffix';
  }

  void _logWarning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'UserProfileStore',
      error: error,
      stackTrace: stackTrace,
    );
  }

  int? _readInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }
}

class _MigrationResult {
  const _MigrationResult(this.data, this.didChange);

  final Map<String, dynamic> data;
  final bool didChange;
}
