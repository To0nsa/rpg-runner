import 'dart:math';

import 'package:flutter/foundation.dart';

/// Sync priority tier used by the hybrid ownership coordinator.
enum OwnershipSyncTier {
  /// Progression-critical mutations must be sent immediately.
  immediateAuthoritative,

  /// High-frequency loadout edits are optimistic and write-behind.
  writeBehind,

  /// Selection changes are optimistic but flushed with strict urgency.
  selectionFastSync,
}

/// Caller intent for flushing queued ownership commands.
enum OwnershipFlushTrigger {
  manual,
  lifecycleInactive,
  lifecyclePaused,
  lifecycleDetached,
  leaveLevelSetup,
  leaveLoadoutSetup,
  runStart,
  connectivityRestored,
}

/// Tunable defaults for hybrid ownership sync behavior.
@immutable
class OwnershipSyncPolicy {
  const OwnershipSyncPolicy({
    required this.tierBDebounceMs,
    required this.tierCDebounceMs,
    required this.maxStalenessMs,
    required this.retryInitialDelayMs,
    required this.retryMaxDelayMs,
    required this.retryJitterRatio,
  });

  /// Default policy aligned with docs/building/hybridWrite/plan.md.
  static const OwnershipSyncPolicy defaults = OwnershipSyncPolicy(
    tierBDebounceMs: 750,
    tierCDebounceMs: 150,
    maxStalenessMs: 8000,
    retryInitialDelayMs: 1000,
    retryMaxDelayMs: 60000,
    retryJitterRatio: 0.20,
  );

  final int tierBDebounceMs;
  final int tierCDebounceMs;
  final int maxStalenessMs;
  final int retryInitialDelayMs;
  final int retryMaxDelayMs;
  final double retryJitterRatio;

  int debounceMsFor(OwnershipSyncTier tier) {
    return switch (tier) {
      OwnershipSyncTier.immediateAuthoritative => 0,
      OwnershipSyncTier.writeBehind => tierBDebounceMs,
      OwnershipSyncTier.selectionFastSync => tierCDebounceMs,
    };
  }

  /// Computes retry delay using exponential backoff plus bounded jitter.
  int retryDelayMsForAttempt(
    int attemptCount, {
    required Random random,
  }) {
    final normalizedAttempts = attemptCount < 0 ? 0 : attemptCount;
    final multiplier = 1 << normalizedAttempts.clamp(0, 30);
    final baseDelay = min(retryInitialDelayMs * multiplier, retryMaxDelayMs);
    if (retryJitterRatio <= 0) {
      return baseDelay;
    }
    final jitterWindow = (baseDelay * retryJitterRatio).round();
    if (jitterWindow <= 0) {
      return baseDelay;
    }
    final offset = random.nextInt(jitterWindow * 2 + 1) - jitterWindow;
    return max(0, baseDelay + offset);
  }
}
