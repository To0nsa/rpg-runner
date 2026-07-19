import 'codecs/json_value_reader.dart';
import 'validated_run.dart';

enum SubmissionRewardStatus {
  none,
  provisional,
  finalReward,
  revoked;

  String get wireValue => switch (this) {
    SubmissionRewardStatus.finalReward => 'final',
    _ => name,
  };

  static SubmissionRewardStatus parse(Object? raw) {
    if (raw is! String) {
      throw FormatException('reward.status must be a string.');
    }
    return switch (raw) {
      'none' => SubmissionRewardStatus.none,
      'provisional' => SubmissionRewardStatus.provisional,
      'final' => SubmissionRewardStatus.finalReward,
      'revoked' => SubmissionRewardStatus.revoked,
      _ => throw FormatException('Unknown reward status: $raw'),
    };
  }
}

final class SubmissionReward {
  SubmissionReward({
    required this.status,
    required this.provisionalGold,
    required this.effectiveGoldDelta,
    required this.spendableGoldDelta,
    required this.updatedAtMs,
    this.grantId,
    this.message,
  }) {
    if (provisionalGold < 0 || updatedAtMs < 0) {
      throw ArgumentError(
        'Submission reward provisionalGold and updatedAtMs must be non-negative.',
      );
    }
    if (grantId != null && grantId!.isEmpty) {
      throw ArgumentError.value(
        grantId,
        'grantId',
        'must be non-empty when set',
      );
    }
    if (message != null && message!.isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'must be non-empty when set',
      );
    }
  }

  final SubmissionRewardStatus status;
  final int provisionalGold;
  final int effectiveGoldDelta;
  final int spendableGoldDelta;
  final int updatedAtMs;
  final String? grantId;
  final String? message;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'status': status.wireValue,
      'provisionalGold': provisionalGold,
      'effectiveGoldDelta': effectiveGoldDelta,
      'spendableGoldDelta': spendableGoldDelta,
      'updatedAtMs': updatedAtMs,
      if (grantId != null) 'grantId': grantId,
      if (message != null) 'message': message,
    };
  }

  factory SubmissionReward.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'submissionStatus.reward');
    return SubmissionReward(
      status: SubmissionRewardStatus.parse(json['status']),
      provisionalGold: readRequiredInt(json, 'provisionalGold'),
      effectiveGoldDelta: readRequiredInt(json, 'effectiveGoldDelta'),
      spendableGoldDelta: readRequiredInt(json, 'spendableGoldDelta'),
      updatedAtMs: readRequiredInt(json, 'updatedAtMs'),
      grantId: readOptionalString(json, 'grantId'),
      message: readOptionalString(json, 'message'),
    );
  }
}

enum RunSessionState {
  issued,
  uploading,
  uploaded,
  pendingValidation,
  validating,
  settlementPending,
  validated,
  rejected,
  expired,
  cancelled,
  internalError;

  String get wireValue => switch (this) {
    RunSessionState.pendingValidation => 'pending_validation',
    RunSessionState.settlementPending => 'settlement_pending',
    RunSessionState.internalError => 'internal_error',
    _ => name,
  };

  static RunSessionState parse(Object? raw) {
    if (raw is! String) {
      throw FormatException('state must be a string.');
    }
    return switch (raw) {
      'issued' => RunSessionState.issued,
      'uploading' => RunSessionState.uploading,
      'uploaded' => RunSessionState.uploaded,
      'pending_validation' => RunSessionState.pendingValidation,
      'validating' => RunSessionState.validating,
      'settlement_pending' => RunSessionState.settlementPending,
      'validated' => RunSessionState.validated,
      'rejected' => RunSessionState.rejected,
      'expired' => RunSessionState.expired,
      'cancelled' => RunSessionState.cancelled,
      'internal_error' => RunSessionState.internalError,
      _ => throw FormatException('Unknown run session state: $raw'),
    };
  }
}

final class SubmissionStatus {
  SubmissionStatus({
    required this.runSessionId,
    required this.state,
    required this.updatedAtMs,
    this.message,
    this.validatedRun,
    this.reward,
  }) {
    if (runSessionId.isEmpty) {
      throw ArgumentError.value(
        runSessionId,
        'runSessionId',
        'must be non-empty',
      );
    }
    if (updatedAtMs < 0) {
      throw ArgumentError.value(
        updatedAtMs,
        'updatedAtMs',
        'must be non-negative',
      );
    }
    if (message != null && message!.isEmpty) {
      throw ArgumentError.value(
        message,
        'message',
        'must be non-empty when set',
      );
    }
    if (validatedRun != null && validatedRun!.runSessionId != runSessionId) {
      throw ArgumentError(
        'validatedRun.runSessionId must match the submission status runSessionId.',
      );
    }
  }

  final String runSessionId;
  final RunSessionState state;
  final int updatedAtMs;
  final String? message;
  final ValidatedRun? validatedRun;
  final SubmissionReward? reward;

  bool get isTerminal => switch (state) {
    RunSessionState.validated ||
    RunSessionState.rejected ||
    RunSessionState.expired ||
    RunSessionState.cancelled ||
    RunSessionState.internalError => true,
    _ => false,
  };

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runSessionId': runSessionId,
      'state': state.wireValue,
      'updatedAtMs': updatedAtMs,
      if (message != null) 'message': message,
      if (validatedRun != null) 'validatedRun': validatedRun!.toJson(),
      if (reward != null) 'reward': reward!.toJson(),
    };
  }

  factory SubmissionStatus.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'submissionStatus');
    return SubmissionStatus(
      runSessionId: readRequiredString(json, 'runSessionId'),
      state: RunSessionState.parse(json['state']),
      updatedAtMs: readRequiredInt(json, 'updatedAtMs'),
      message: readOptionalString(json, 'message'),
      validatedRun: json['validatedRun'] == null
          ? null
          : ValidatedRun.fromJson(json['validatedRun']),
      reward: json['reward'] == null
          ? null
          : SubmissionReward.fromJson(json['reward']),
    );
  }
}
