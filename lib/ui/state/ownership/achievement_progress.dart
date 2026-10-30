/// Confirmed achievement evidence. Thresholds and rewards come from the backend;
/// client progress never determines whether a reward can be granted.
final class AchievementProgress {
  const AchievementProgress._(this.entries);
  static const empty = AchievementProgress._([]);
  final List<AchievementEntry> entries;

  int get claimableGold =>
      _count(entries.fold<int>(0, (sum, entry) => sum + entry.claimableGold));
  bool get hasRewards => claimableGold > 0;

  factory AchievementProgress.fromJson(Object? raw) {
    if (raw == null) return empty;
    final json = _object(raw);
    final entries = json['entries'];
    if (json['schemaVersion'] != 1 || entries is! List || entries.length > 64) {
      throw const FormatException('Unsupported achievement progress.');
    }
    final parsed = entries.map(AchievementEntry._fromJson).toList();
    if (parsed.map((entry) => entry.id).toSet().length != parsed.length) {
      throw const FormatException('Duplicate achievement.');
    }
    return AchievementProgress._(List.unmodifiable(parsed));
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'entries': [for (final entry in entries) entry.toJson()],
  };
}

final class AchievementEntry {
  const AchievementEntry._(this.id, this.value, this.tiers);
  final String id;
  final int value;
  final List<AchievementTier> tiers;
  AchievementTier? get nextTier =>
      tiers.where((tier) => !tier.achieved).firstOrNull;
  bool get completed => nextTier == null;
  int get claimableGold => _count(
    tiers.fold<int>(
      0,
      (sum, tier) => sum + (tier.canClaim ? tier.goldAmount : 0),
    ),
  );

  factory AchievementEntry._fromJson(Object? raw) {
    final json = _object(raw);
    final id = json['id'];
    final rawTiers = json['tiers'];
    if (id is! String ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$').hasMatch(id) ||
        rawTiers is! List ||
        rawTiers.length != 3) {
      throw const FormatException('Invalid achievement.');
    }
    final value = _count(json['value']);
    final tiers = rawTiers.map(AchievementTier._fromJson).toList();
    var previousThreshold = 0;
    var previousUnearned = false;
    for (final tier in tiers) {
      if (tier.threshold <= previousThreshold ||
          (tier.achieved && (previousUnearned || value < tier.threshold))) {
        throw const FormatException('Invalid achievement tiers.');
      }
      previousThreshold = tier.threshold;
      previousUnearned = !tier.achieved;
    }
    return AchievementEntry._(id, value, List.unmodifiable(tiers));
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'value': value,
    'tiers': [for (final tier in tiers) tier.toJson()],
  };
}

final class AchievementTier {
  const AchievementTier._({
    required this.threshold,
    required this.goldAmount,
    required this.achievedAtMs,
    required this.claimedAtMs,
  });
  final int threshold, goldAmount;

  /// Server confirmation and claim times, in UTC epoch milliseconds.
  final int? achievedAtMs, claimedAtMs;
  bool get achieved => achievedAtMs != null;
  bool get canClaim => achieved && claimedAtMs == null;

  factory AchievementTier._fromJson(Object? raw) {
    final json = _object(raw);
    final threshold = _count(json['threshold']);
    final gold = _count(json['goldAmount']);
    final achieved = _timestamp(json['achievedAtMs']);
    final claimed = _timestamp(json['claimedAtMs']);
    if (threshold == 0 ||
        gold == 0 ||
        (claimed != null && (achieved == null || claimed < achieved))) {
      throw const FormatException('Invalid achievement reward.');
    }
    return AchievementTier._(
      threshold: threshold,
      goldAmount: gold,
      achievedAtMs: achieved,
      claimedAtMs: claimed,
    );
  }

  Map<String, Object?> toJson() => {
    'threshold': threshold,
    'goldAmount': goldAmount,
    'achievedAtMs': achievedAtMs,
    'claimedAtMs': claimedAtMs,
  };
}

Map<Object?, Object?> _object(Object? raw) {
  if (raw is! Map) throw const FormatException('Invalid achievement object.');
  return raw;
}

int _count(Object? raw) {
  if (raw is! int || raw < 0 || raw > 9007199254740991) {
    throw const FormatException('Invalid achievement count.');
  }
  return raw;
}

int? _timestamp(Object? raw) {
  if (raw == null) return null;
  final value = _count(raw);
  if (value > 8640000000000000) {
    throw const FormatException('Invalid achievement date.');
  }
  return value;
}
