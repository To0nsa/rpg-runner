import 'package:run_protocol/submission_status.dart' as protocol;

import 'pending_run_submission.dart';

enum RunSubmissionPhase {
  queued,
  requestingUploadGrant,
  uploading,
  finalizing,
  retryScheduled,
  pendingValidation,
  validating,
  validated,
  rejected,
  expired,
  cancelled,
  internalError;

  bool get isTerminal => switch (this) {
    RunSubmissionPhase.validated ||
    RunSubmissionPhase.rejected ||
    RunSubmissionPhase.expired ||
    RunSubmissionPhase.cancelled ||
    RunSubmissionPhase.internalError => true,
    _ => false,
  };
}

final class RunSubmissionStatus {
  const RunSubmissionStatus({
    required this.runSessionId,
    required this.phase,
    required this.updatedAtMs,
    this.message,
    this.nextRetryAtMs,
    this.verificationDelayed = false,
    this.serverStatus,
    this.pendingSubmission,
  }) : assert(updatedAtMs >= 0);

  static const int defaultVerificationDelayedThresholdMs = 5 * 60 * 1000;

  final String runSessionId;
  final RunSubmissionPhase phase;
  final int updatedAtMs;
  final String? message;
  final int? nextRetryAtMs;
  final bool verificationDelayed;
  final protocol.SubmissionStatus? serverStatus;
  final PendingRunSubmission? pendingSubmission;

  protocol.SubmissionReward? get reward => serverStatus?.reward;

  int get provisionalGold => reward?.provisionalGold ?? 0;

  int get spendableGoldDelta => reward?.spendableGoldDelta ?? 0;

  bool get hasProvisionalReward =>
      reward?.status == protocol.SubmissionRewardStatus.provisional;

  bool get isRewardFinal =>
      reward?.status == protocol.SubmissionRewardStatus.finalReward;

  bool get isRewardRevoked =>
      reward?.status == protocol.SubmissionRewardStatus.revoked;

  int get displayProvisionalGold {
    if (hasProvisionalReward) {
      return provisionalGold > 0 ? provisionalGold : 0;
    }
    if (isTerminal) {
      return 0;
    }
    final raw = pendingSubmission?.provisionalSummary?['goldEarned'];
    if (raw is int) {
      return raw > 0 ? raw : 0;
    }
    if (raw is num) {
      final value = raw.toInt();
      return value > 0 ? value : 0;
    }
    return 0;
  }

  bool get isTerminal => phase.isTerminal;

  factory RunSubmissionStatus.fromPending(
    PendingRunSubmission pending, {
    int? nowMs,
    int verificationDelayedThresholdMs = defaultVerificationDelayedThresholdMs,
  }) {
    final effectiveNowMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final phase = switch (pending.step) {
      PendingRunSubmissionStep.queued => RunSubmissionPhase.queued,
      PendingRunSubmissionStep.requestingUploadGrant =>
        RunSubmissionPhase.requestingUploadGrant,
      PendingRunSubmissionStep.uploading => RunSubmissionPhase.uploading,
      PendingRunSubmissionStep.finalizing => RunSubmissionPhase.finalizing,
      PendingRunSubmissionStep.awaitingServerStatus =>
        RunSubmissionPhase.pendingValidation,
      PendingRunSubmissionStep.retryScheduled =>
        RunSubmissionPhase.retryScheduled,
    };
    final verificationDelayed =
        phase == RunSubmissionPhase.pendingValidation &&
        effectiveNowMs - pending.updatedAtMs >= verificationDelayedThresholdMs;
    return RunSubmissionStatus(
      runSessionId: pending.runSessionId,
      phase: phase,
      updatedAtMs: pending.updatedAtMs,
      message: pending.lastErrorMessage,
      nextRetryAtMs: pending.step == PendingRunSubmissionStep.retryScheduled
          ? pending.nextAttemptAtMs
          : null,
      verificationDelayed: verificationDelayed,
      pendingSubmission: pending,
    );
  }

  factory RunSubmissionStatus.fromServerStatus(
    protocol.SubmissionStatus status, {
    PendingRunSubmission? pendingSubmission,
    int? nowMs,
    int verificationDelayedThresholdMs = defaultVerificationDelayedThresholdMs,
  }) {
    final phase = switch (status.state) {
      protocol.RunSessionState.issued => RunSubmissionPhase.queued,
      protocol.RunSessionState.uploading => RunSubmissionPhase.uploading,
      protocol.RunSessionState.uploaded => RunSubmissionPhase.finalizing,
      protocol.RunSessionState.pendingValidation =>
        RunSubmissionPhase.pendingValidation,
      protocol.RunSessionState.validating => RunSubmissionPhase.validating,
      protocol.RunSessionState.validated => RunSubmissionPhase.validated,
      protocol.RunSessionState.rejected => RunSubmissionPhase.rejected,
      protocol.RunSessionState.expired => RunSubmissionPhase.expired,
      protocol.RunSessionState.cancelled => RunSubmissionPhase.cancelled,
      protocol.RunSessionState.internalError =>
        RunSubmissionPhase.internalError,
    };
    final effectiveNowMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final verificationDelayed =
        (phase == RunSubmissionPhase.pendingValidation ||
            phase == RunSubmissionPhase.validating) &&
        effectiveNowMs - status.updatedAtMs >= verificationDelayedThresholdMs;
    return RunSubmissionStatus(
      runSessionId: status.runSessionId,
      phase: phase,
      updatedAtMs: status.updatedAtMs,
      message: status.message,
      verificationDelayed: verificationDelayed,
      serverStatus: status,
      pendingSubmission: pendingSubmission,
    );
  }
}
