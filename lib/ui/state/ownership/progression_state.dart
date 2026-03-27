enum StoreBucket {
  sword,
  shield,
  accessory,
  spellBook,
  projectileSpell,
  spell,
  ability,
}

enum StoreDomain { gear, projectileSpell, ability }

enum StoreSlot {
  mainWeapon,
  offhandWeapon,
  spellBook,
  accessory,
  primary,
  secondary,
  projectile,
  mobility,
  jump,
  spell,
}

enum StoreRefreshMethod { gold, rewardedAd }

class StoreOfferState {
  const StoreOfferState({
    required this.offerId,
    required this.bucket,
    required this.domain,
    required this.slot,
    required this.itemId,
    required this.priceGold,
  });

  final String offerId;
  final StoreBucket bucket;
  final StoreDomain domain;
  final StoreSlot slot;
  final String itemId;
  final int priceGold;

  StoreOfferState copyWith({
    String? offerId,
    StoreBucket? bucket,
    StoreDomain? domain,
    StoreSlot? slot,
    String? itemId,
    int? priceGold,
  }) {
    return StoreOfferState(
      offerId: offerId ?? this.offerId,
      bucket: bucket ?? this.bucket,
      domain: domain ?? this.domain,
      slot: slot ?? this.slot,
      itemId: itemId ?? this.itemId,
      priceGold: priceGold ?? this.priceGold,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'offerId': offerId,
      'bucket': bucket.name,
      'domain': domain.name,
      'slot': slot.name,
      'itemId': itemId,
      'priceGold': priceGold,
    };
  }

  factory StoreOfferState.fromJson(Map<String, dynamic> json) {
    final offerIdRaw = json['offerId'];
    final bucketRaw = json['bucket'];
    final domainRaw = json['domain'];
    final slotRaw = json['slot'];
    final itemIdRaw = json['itemId'];
    final priceGoldRaw = json['priceGold'];
    final bucket =
        _enumByName(StoreBucket.values, bucketRaw as String?) ??
        StoreBucket.sword;
    final domain =
        _enumByName(StoreDomain.values, domainRaw as String?) ??
        StoreDomain.gear;
    final slot =
        _enumByName(StoreSlot.values, slotRaw as String?) ??
        StoreSlot.mainWeapon;
    final itemId = itemIdRaw is String ? itemIdRaw.trim() : '';
    final resolvedOfferId = offerIdRaw is String && offerIdRaw.trim().isNotEmpty
        ? offerIdRaw.trim()
        : '${domain.name}:${slot.name}:$itemId';
    final priceGold = priceGoldRaw is int
        ? priceGoldRaw
        : (priceGoldRaw is num ? priceGoldRaw.toInt() : 0);
    return StoreOfferState(
      offerId: resolvedOfferId,
      bucket: bucket,
      domain: domain,
      slot: slot,
      itemId: itemId,
      priceGold: priceGold < 0 ? 0 : priceGold,
    );
  }
}

class TownStoreState {
  const TownStoreState({
    required this.schemaVersion,
    required this.generation,
    required this.refreshDayKeyUtc,
    required this.refreshesUsedToday,
    required this.activeOffers,
  });

  final int schemaVersion;
  final int generation;
  final String refreshDayKeyUtc;
  final int refreshesUsedToday;
  final List<StoreOfferState> activeOffers;

  static const TownStoreState initial = TownStoreState(
    schemaVersion: 1,
    generation: 0,
    refreshDayKeyUtc: '',
    refreshesUsedToday: 0,
    activeOffers: <StoreOfferState>[],
  );

  TownStoreState copyWith({
    int? schemaVersion,
    int? generation,
    String? refreshDayKeyUtc,
    int? refreshesUsedToday,
    List<StoreOfferState>? activeOffers,
  }) {
    return TownStoreState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      generation: generation ?? this.generation,
      refreshDayKeyUtc: refreshDayKeyUtc ?? this.refreshDayKeyUtc,
      refreshesUsedToday: refreshesUsedToday ?? this.refreshesUsedToday,
      activeOffers: activeOffers ?? this.activeOffers,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'generation': generation,
      'refreshDayKeyUtc': refreshDayKeyUtc,
      'refreshesUsedToday': refreshesUsedToday,
      'activeOffers': activeOffers.map((offer) => offer.toJson()).toList(),
    };
  }

  factory TownStoreState.fromJson(Map<String, dynamic> json) {
    final schemaVersionRaw = json['schemaVersion'];
    final generationRaw = json['generation'];
    final refreshDayKeyUtcRaw = json['refreshDayKeyUtc'];
    final refreshesUsedTodayRaw = json['refreshesUsedToday'];
    final activeOffersRaw = json['activeOffers'];
    final activeOffers = <StoreOfferState>[];
    if (activeOffersRaw is List) {
      for (final raw in activeOffersRaw) {
        if (raw is Map<String, dynamic>) {
          final parsed = StoreOfferState.fromJson(raw);
          if (parsed.itemId.isNotEmpty) {
            activeOffers.add(parsed);
          }
          continue;
        }
        if (raw is Map) {
          final parsed = StoreOfferState.fromJson(
            Map<String, dynamic>.from(raw),
          );
          if (parsed.itemId.isNotEmpty) {
            activeOffers.add(parsed);
          }
        }
      }
    }
    final schemaVersion = schemaVersionRaw is int
        ? schemaVersionRaw
        : (schemaVersionRaw is num ? schemaVersionRaw.toInt() : 1);
    final generation = generationRaw is int
        ? generationRaw
        : (generationRaw is num ? generationRaw.toInt() : 0);
    final refreshesUsedToday = refreshesUsedTodayRaw is int
        ? refreshesUsedTodayRaw
        : (refreshesUsedTodayRaw is num ? refreshesUsedTodayRaw.toInt() : 0);
    final refreshDayKeyUtc = refreshDayKeyUtcRaw is String
        ? refreshDayKeyUtcRaw
        : '';
    return TownStoreState(
      schemaVersion: schemaVersion < 0 ? 0 : schemaVersion,
      generation: generation < 0 ? 0 : generation,
      refreshDayKeyUtc: refreshDayKeyUtc,
      refreshesUsedToday: refreshesUsedToday < 0 ? 0 : refreshesUsedToday,
      activeOffers: activeOffers,
    );
  }
}

class WeeklyProgressState {
  const WeeklyProgressState({
    required this.schemaVersion,
    required this.currentWindowId,
    required this.currentWindowValidatedRuns,
    required this.currentWindowGoldEarned,
    required this.lifetimeValidatedRuns,
    required this.lifetimeGoldEarned,
    required this.lastWindowId,
    required this.lastBoardId,
    required this.lastRunSessionId,
    required this.lastRewardGrantId,
    required this.lastValidatedAtMs,
  });

  final int schemaVersion;
  final String currentWindowId;
  final int currentWindowValidatedRuns;
  final int currentWindowGoldEarned;
  final int lifetimeValidatedRuns;
  final int lifetimeGoldEarned;
  final String lastWindowId;
  final String lastBoardId;
  final String lastRunSessionId;
  final String lastRewardGrantId;
  final int lastValidatedAtMs;

  static const WeeklyProgressState initial = WeeklyProgressState(
    schemaVersion: 1,
    currentWindowId: '',
    currentWindowValidatedRuns: 0,
    currentWindowGoldEarned: 0,
    lifetimeValidatedRuns: 0,
    lifetimeGoldEarned: 0,
    lastWindowId: '',
    lastBoardId: '',
    lastRunSessionId: '',
    lastRewardGrantId: '',
    lastValidatedAtMs: 0,
  );

  WeeklyProgressState copyWith({
    int? schemaVersion,
    String? currentWindowId,
    int? currentWindowValidatedRuns,
    int? currentWindowGoldEarned,
    int? lifetimeValidatedRuns,
    int? lifetimeGoldEarned,
    String? lastWindowId,
    String? lastBoardId,
    String? lastRunSessionId,
    String? lastRewardGrantId,
    int? lastValidatedAtMs,
  }) {
    return WeeklyProgressState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      currentWindowId: currentWindowId ?? this.currentWindowId,
      currentWindowValidatedRuns:
          currentWindowValidatedRuns ?? this.currentWindowValidatedRuns,
      currentWindowGoldEarned:
          currentWindowGoldEarned ?? this.currentWindowGoldEarned,
      lifetimeValidatedRuns: lifetimeValidatedRuns ?? this.lifetimeValidatedRuns,
      lifetimeGoldEarned: lifetimeGoldEarned ?? this.lifetimeGoldEarned,
      lastWindowId: lastWindowId ?? this.lastWindowId,
      lastBoardId: lastBoardId ?? this.lastBoardId,
      lastRunSessionId: lastRunSessionId ?? this.lastRunSessionId,
      lastRewardGrantId: lastRewardGrantId ?? this.lastRewardGrantId,
      lastValidatedAtMs: lastValidatedAtMs ?? this.lastValidatedAtMs,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'currentWindowId': currentWindowId,
      'currentWindowValidatedRuns': currentWindowValidatedRuns,
      'currentWindowGoldEarned': currentWindowGoldEarned,
      'lifetimeValidatedRuns': lifetimeValidatedRuns,
      'lifetimeGoldEarned': lifetimeGoldEarned,
      'lastWindowId': lastWindowId,
      'lastBoardId': lastBoardId,
      'lastRunSessionId': lastRunSessionId,
      'lastRewardGrantId': lastRewardGrantId,
      'lastValidatedAtMs': lastValidatedAtMs,
    };
  }

  factory WeeklyProgressState.fromJson(Map<String, dynamic> json) {
    return WeeklyProgressState(
      schemaVersion: _toInt(json['schemaVersion'], fallback: 1),
      currentWindowId: _toString(json['currentWindowId']),
      currentWindowValidatedRuns: _toInt(
        json['currentWindowValidatedRuns'],
        fallback: 0,
      ),
      currentWindowGoldEarned: _toInt(
        json['currentWindowGoldEarned'],
        fallback: 0,
      ),
      lifetimeValidatedRuns: _toInt(json['lifetimeValidatedRuns'], fallback: 0),
      lifetimeGoldEarned: _toInt(json['lifetimeGoldEarned'], fallback: 0),
      lastWindowId: _toString(json['lastWindowId']),
      lastBoardId: _toString(json['lastBoardId']),
      lastRunSessionId: _toString(json['lastRunSessionId']),
      lastRewardGrantId: _toString(json['lastRewardGrantId']),
      lastValidatedAtMs: _toInt(json['lastValidatedAtMs'], fallback: 0),
    );
  }
}

class ProgressionState {
  const ProgressionState({
    required this.gold,
    this.store = TownStoreState.initial,
    this.weekly = WeeklyProgressState.initial,
  });

  final int gold;
  final TownStoreState store;
  final WeeklyProgressState weekly;

  static const ProgressionState initial = ProgressionState(
    gold: 0,
    store: TownStoreState.initial,
    weekly: WeeklyProgressState.initial,
  );

  ProgressionState copyWith({
    int? gold,
    TownStoreState? store,
    WeeklyProgressState? weekly,
  }) {
    return ProgressionState(
      gold: gold ?? this.gold,
      store: store ?? this.store,
      weekly: weekly ?? this.weekly,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'gold': gold,
      'store': store.toJson(),
      'weeklyProgress': weekly.toJson(),
    };
  }

  factory ProgressionState.fromJson(Map<String, dynamic> json) {
    final goldRaw = json['gold'];
    final storeRaw = json['store'];
    final weeklyRaw = json['weeklyProgress'];
    final gold = goldRaw is int
        ? goldRaw
        : (goldRaw is num ? goldRaw.toInt() : 0);
    final store = storeRaw is Map<String, dynamic>
        ? TownStoreState.fromJson(storeRaw)
        : (storeRaw is Map
              ? TownStoreState.fromJson(Map<String, dynamic>.from(storeRaw))
              : TownStoreState.initial);
    final weekly = weeklyRaw is Map<String, dynamic>
        ? WeeklyProgressState.fromJson(weeklyRaw)
        : (weeklyRaw is Map
              ? WeeklyProgressState.fromJson(
                  Map<String, dynamic>.from(weeklyRaw),
                )
              : WeeklyProgressState.initial);
    return ProgressionState(
      gold: gold < 0 ? 0 : gold,
      store: store,
      weekly: weekly,
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null || name.isEmpty) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

int _toInt(Object? raw, {required int fallback}) {
  final value = raw is int ? raw : (raw is num ? raw.toInt() : fallback);
  return value < 0 ? 0 : value;
}

String _toString(Object? raw) {
  if (raw is! String) {
    return '';
  }
  return raw.trim();
}
