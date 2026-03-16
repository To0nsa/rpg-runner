import 'package:flutter/foundation.dart';

/// Runtime visibility for hybrid ownership sync health.
@immutable
class OwnershipSyncStatus {
  const OwnershipSyncStatus({
    required this.pendingCount,
    required this.pendingSelectionCount,
    required this.oldestPendingAgeMs,
    required this.isFlushing,
    required this.retryCount,
    required this.conflictCount,
    this.lastSyncError,
  });

  static const OwnershipSyncStatus idle = OwnershipSyncStatus(
    pendingCount: 0,
    pendingSelectionCount: 0,
    oldestPendingAgeMs: 0,
    isFlushing: false,
    retryCount: 0,
    conflictCount: 0,
  );

  final int pendingCount;
  final int pendingSelectionCount;
  final int oldestPendingAgeMs;
  final bool isFlushing;
  final int retryCount;
  final int conflictCount;
  final String? lastSyncError;

  OwnershipSyncStatus copyWith({
    int? pendingCount,
    int? pendingSelectionCount,
    int? oldestPendingAgeMs,
    bool? isFlushing,
    int? retryCount,
    int? conflictCount,
    String? lastSyncError,
    bool clearLastSyncError = false,
  }) {
    return OwnershipSyncStatus(
      pendingCount: pendingCount ?? this.pendingCount,
      pendingSelectionCount: pendingSelectionCount ?? this.pendingSelectionCount,
      oldestPendingAgeMs: oldestPendingAgeMs ?? this.oldestPendingAgeMs,
      isFlushing: isFlushing ?? this.isFlushing,
      retryCount: retryCount ?? this.retryCount,
      conflictCount: conflictCount ?? this.conflictCount,
      lastSyncError: clearLastSyncError
          ? null
          : (lastSyncError ?? this.lastSyncError),
    );
  }
}
