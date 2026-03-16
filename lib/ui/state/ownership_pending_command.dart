import 'package:flutter/foundation.dart';

import 'ownership_sync_policy.dart';

/// Command types that can be queued in the ownership outbox.
enum OwnershipPendingCommandType {
  setSelection,
  setLoadout,
  setAbilitySlot,
  setProjectileSpell,
  equipGear,
}

/// Delivery metadata retained across retries for idempotent replay.
@immutable
class OwnershipDeliveryAttempt {
  const OwnershipDeliveryAttempt({
    required this.commandId,
    required this.expectedRevision,
    required this.attemptCount,
    required this.nextAttemptAtMs,
    required this.sentPayloadHash,
  });

  final String commandId;
  final int expectedRevision;
  final int attemptCount;
  final int nextAttemptAtMs;
  final String sentPayloadHash;

  OwnershipDeliveryAttempt copyWith({
    String? commandId,
    int? expectedRevision,
    int? attemptCount,
    int? nextAttemptAtMs,
    String? sentPayloadHash,
  }) {
    return OwnershipDeliveryAttempt(
      commandId: commandId ?? this.commandId,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
      sentPayloadHash: sentPayloadHash ?? this.sentPayloadHash,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'commandId': commandId,
      'expectedRevision': expectedRevision,
      'attemptCount': attemptCount,
      'nextAttemptAtMs': nextAttemptAtMs,
      'sentPayloadHash': sentPayloadHash,
    };
  }

  static OwnershipDeliveryAttempt? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(raw);
    final commandId = map['commandId'];
    final expectedRevision = map['expectedRevision'];
    final attemptCount = map['attemptCount'];
    final nextAttemptAtMs = map['nextAttemptAtMs'];
    final sentPayloadHash = map['sentPayloadHash'];
    if (commandId is! String || commandId.trim().isEmpty) {
      return null;
    }
    if (expectedRevision is! num || attemptCount is! num) {
      return null;
    }
    if (nextAttemptAtMs is! num || sentPayloadHash is! String) {
      return null;
    }
    return OwnershipDeliveryAttempt(
      commandId: commandId,
      expectedRevision: expectedRevision.toInt(),
      attemptCount: attemptCount.toInt(),
      nextAttemptAtMs: nextAttemptAtMs.toInt(),
      sentPayloadHash: sentPayloadHash,
    );
  }
}

/// Durable queued ownership command used by hybrid sync.
@immutable
class OwnershipPendingCommand {
  const OwnershipPendingCommand({
    required this.coalesceKey,
    required this.commandType,
    required this.policyTier,
    required this.payloadJson,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deliveryAttempt,
  });

  final String coalesceKey;
  final OwnershipPendingCommandType commandType;
  final OwnershipSyncTier policyTier;
  final Map<String, Object?> payloadJson;
  final int createdAtMs;
  final int updatedAtMs;
  final OwnershipDeliveryAttempt? deliveryAttempt;

  OwnershipPendingCommand copyWith({
    String? coalesceKey,
    OwnershipPendingCommandType? commandType,
    OwnershipSyncTier? policyTier,
    Map<String, Object?>? payloadJson,
    int? createdAtMs,
    int? updatedAtMs,
    OwnershipDeliveryAttempt? deliveryAttempt,
    bool clearDeliveryAttempt = false,
  }) {
    return OwnershipPendingCommand(
      coalesceKey: coalesceKey ?? this.coalesceKey,
      commandType: commandType ?? this.commandType,
      policyTier: policyTier ?? this.policyTier,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deliveryAttempt: clearDeliveryAttempt
          ? null
          : (deliveryAttempt ?? this.deliveryAttempt),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'coalesceKey': coalesceKey,
      'commandType': commandType.name,
      'policyTier': policyTier.name,
      'payloadJson': payloadJson,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
      if (deliveryAttempt != null) 'deliveryAttempt': deliveryAttempt!.toJson(),
    };
  }

  static OwnershipPendingCommand? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(raw);
    final coalesceKey = map['coalesceKey'];
    final commandType = _commandTypeFromName(map['commandType']);
    final policyTier = _syncTierFromName(map['policyTier']);
    final payloadJson = _decodePayload(map['payloadJson']);
    final createdAtMs = map['createdAtMs'];
    final updatedAtMs = map['updatedAtMs'];

    if (coalesceKey is! String || coalesceKey.trim().isEmpty) {
      return null;
    }
    if (commandType == null || policyTier == null || payloadJson == null) {
      return null;
    }
    if (createdAtMs is! num || updatedAtMs is! num) {
      return null;
    }

    return OwnershipPendingCommand(
      coalesceKey: coalesceKey,
      commandType: commandType,
      policyTier: policyTier,
      payloadJson: payloadJson,
      createdAtMs: createdAtMs.toInt(),
      updatedAtMs: updatedAtMs.toInt(),
      deliveryAttempt: OwnershipDeliveryAttempt.fromJson(map['deliveryAttempt']),
    );
  }

  static OwnershipPendingCommandType? _commandTypeFromName(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final value in OwnershipPendingCommandType.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }

  static OwnershipSyncTier? _syncTierFromName(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final value in OwnershipSyncTier.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }

  static Map<String, Object?>? _decodePayload(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) {
        return null;
      }
      final value = _normalizeJsonValue(entry.value);
      if (value == _invalidJsonMarker) {
        return null;
      }
      normalized[key] = value;
    }
    return normalized;
  }

  static const Object _invalidJsonMarker = Object();

  static Object? _normalizeJsonValue(Object? value) {
    if (value == null || value is bool || value is String || value is num) {
      return value;
    }
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          return _invalidJsonMarker;
        }
        final child = _normalizeJsonValue(entry.value);
        if (child == _invalidJsonMarker) {
          return _invalidJsonMarker;
        }
        normalized[key] = child;
      }
      return normalized;
    }
    if (value is List) {
      final normalized = <Object?>[];
      for (final item in value) {
        final child = _normalizeJsonValue(item);
        if (child == _invalidJsonMarker) {
          return _invalidJsonMarker;
        }
        normalized.add(child);
      }
      return normalized;
    }
    return _invalidJsonMarker;
  }
}
