import 'package:flutter/foundation.dart';

class ChargePreviewState {
  const ChargePreviewState({
    required this.active,
    required this.ownerId,
    required this.chargeTicks,
    required this.halfTierTicks,
    required this.fullTierTicks,
    required this.progress01,
    required this.tier,
  });

  static const ChargePreviewState inactive = ChargePreviewState(
    active: false,
    ownerId: null,
    chargeTicks: 0,
    halfTierTicks: 0,
    fullTierTicks: 0,
    progress01: 0.0,
    tier: 0,
  );

  final bool active;
  final String? ownerId;
  final int chargeTicks;
  final int halfTierTicks;
  final int fullTierTicks;
  final double progress01;
  final int tier;
}

class ChargePreviewModel extends ValueNotifier<ChargePreviewState> {
  ChargePreviewModel() : super(ChargePreviewState.inactive);

  void begin({
    required String ownerId,
    required int halfTierTicks,
    required int fullTierTicks,
  }) {
    final safeHalf = halfTierTicks <= 0 ? 1 : halfTierTicks;
    final safeFull = fullTierTicks <= safeHalf ? safeHalf + 1 : fullTierTicks;
    value = ChargePreviewState(
      active: true,
      ownerId: ownerId,
      chargeTicks: 0,
      halfTierTicks: safeHalf,
      fullTierTicks: safeFull,
      progress01: 0.0,
      tier: 0,
    );
  }

  void updateChargeTicks(int chargeTicks) {
    final current = value;
    if (!current.active) return;
    final safeTicks = chargeTicks < 0 ? 0 : chargeTicks;
    final full = current.fullTierTicks <= 0 ? 1 : current.fullTierTicks;
    final progress = (safeTicks / full).clamp(0.0, 1.0);
    final tier = safeTicks >= current.fullTierTicks
        ? 2
        : (safeTicks >= current.halfTierTicks ? 1 : 0);
    value = ChargePreviewState(
      active: true,
      ownerId: current.ownerId,
      chargeTicks: safeTicks,
      halfTierTicks: current.halfTierTicks,
      fullTierTicks: current.fullTierTicks,
      progress01: progress,
      tier: tier,
    );
  }

  void end() {
    value = ChargePreviewState.inactive;
  }
}
