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

class ProgressionState {
  const ProgressionState({
    required this.gold,
    this.store = TownStoreState.initial,
  });

  final int gold;
  final TownStoreState store;

  static const ProgressionState initial = ProgressionState(
    gold: 0,
    store: TownStoreState.initial,
  );

  ProgressionState copyWith({int? gold, TownStoreState? store}) {
    return ProgressionState(
      gold: gold ?? this.gold,
      store: store ?? this.store,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'gold': gold, 'store': store.toJson()};
  }

  factory ProgressionState.fromJson(Map<String, dynamic> json) {
    final goldRaw = json['gold'];
    final storeRaw = json['store'];
    final gold = goldRaw is int
        ? goldRaw
        : (goldRaw is num ? goldRaw.toInt() : 0);
    final store = storeRaw is Map<String, dynamic>
        ? TownStoreState.fromJson(storeRaw)
        : (storeRaw is Map
              ? TownStoreState.fromJson(Map<String, dynamic>.from(storeRaw))
              : TownStoreState.initial);
    return ProgressionState(gold: gold < 0 ? 0 : gold, store: store);
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
