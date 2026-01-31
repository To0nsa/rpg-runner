class UserProfile {
  UserProfile({
    required this.schemaVersion,
    required this.profileId,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.revision,
    required Map<String, bool> flags,
    required Map<String, int> counters,
  })  : flags = Map<String, bool>.unmodifiable(flags),
        counters = Map<String, int>.unmodifiable(counters);

  static const int latestSchemaVersion = 1;

  final int schemaVersion;
  final String profileId;
  final int createdAtMs;
  final int updatedAtMs;
  final int revision;
  final Map<String, bool> flags;
  final Map<String, int> counters;

  static UserProfile empty() {
    return UserProfile(
      schemaVersion: latestSchemaVersion,
      profileId: 'guest',
      createdAtMs: 0,
      updatedAtMs: 0,
      revision: 0,
      flags: const <String, bool>{},
      counters: const <String, int>{},
    );
  }

  static UserProfile createNew({
    required String profileId,
    required int nowMs,
  }) {
    return UserProfile(
      schemaVersion: latestSchemaVersion,
      profileId: profileId,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
      revision: 0,
      flags: const <String, bool>{},
      counters: const <String, int>{},
    );
  }

  UserProfile copyWith({
    int? schemaVersion,
    String? profileId,
    int? createdAtMs,
    int? updatedAtMs,
    int? revision,
    Map<String, bool>? flags,
    Map<String, int>? counters,
  }) {
    return UserProfile(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      profileId: profileId ?? this.profileId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      revision: revision ?? this.revision,
      flags: flags ?? this.flags,
      counters: counters ?? this.counters,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
      'revision': revision,
      'flags': flags,
      'counters': counters,
    };
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    required String fallbackProfileId,
    required int nowMs,
  }) {
    final schemaVersion =
        _readInt(json['schemaVersion']) ?? latestSchemaVersion;
    final profileId = _readString(json['profileId']) ?? fallbackProfileId;
    final createdAtMs = _readInt(json['createdAtMs']) ?? nowMs;
    final updatedAtMs = _readInt(json['updatedAtMs']) ?? createdAtMs;
    final revision = _readInt(json['revision']) ?? 0;
    final flags = _readBoolMap(json['flags']);
    final counters = _readIntMap(json['counters']);

    return UserProfile(
      schemaVersion: schemaVersion,
      profileId: profileId,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs,
      revision: revision,
      flags: flags,
      counters: counters,
    );
  }
}

int? _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return null;
}

String? _readString(Object? raw) {
  if (raw is String && raw.isNotEmpty) return raw;
  return null;
}

Map<String, bool> _readBoolMap(Object? raw) {
  if (raw is! Map) return <String, bool>{};
  final map = <String, bool>{};
  raw.forEach((key, value) {
    if (key is String && value is bool) {
      map[key] = value;
    }
  });
  return map;
}

Map<String, int> _readIntMap(Object? raw) {
  if (raw is! Map) return <String, int>{};
  final map = <String, int>{};
  raw.forEach((key, value) {
    if (key is! String) return;
    if (value is int) {
      map[key] = value;
      return;
    }
    if (value is num) {
      map[key] = value.toInt();
    }
  });
  return map;
}
