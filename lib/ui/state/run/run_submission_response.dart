import 'package:run_protocol/submission_status.dart';
import 'package:runner_core/meta/meta_service.dart';

import '../ownership/loadout_ownership_api.dart';
import '../ownership/progression_state.dart';
import '../ownership/selection_state.dart';

/// Account data travels beside the replay protocol, within the UI/backend layer.
final class RunSubmissionResponse {
  const RunSubmissionResponse(this.status, {this.canonical});

  final SubmissionStatus status;
  final OwnershipCanonicalState? canonical;

  factory RunSubmissionResponse.fromJson(
    Map<String, dynamic> response, {
    required String userId,
    required String runSessionId,
  }) {
    final status = SubmissionStatus.fromJson(
      response['submissionStatus'] ?? response,
    );
    if (status.runSessionId != runSessionId) {
      throw const FormatException('Submission belongs to another run.');
    }
    final raw = response['completion'];
    if (raw == null) return RunSubmissionResponse(status);
    final completion = RunSubmissionResponse.fromReceipt(
      raw,
      userId: userId,
      runSessionId: runSessionId,
    );
    if (status.state != completion.status.state ||
        status.reward?.grantId != completion.status.reward?.grantId ||
        status.reward?.spendableGoldDelta !=
            completion.status.reward?.spendableGoldDelta) {
      throw const FormatException(
        'Completion disagrees with submission status.',
      );
    }
    return RunSubmissionResponse(status, canonical: completion.canonical);
  }

  factory RunSubmissionResponse.fromReceipt(
    Object? raw, {
    required String userId,
    required String runSessionId,
  }) {
    if (raw is! Map ||
        raw['schemaVersion'] != 1 ||
        raw['uid'] != userId ||
        raw['runSessionId'] != runSessionId) {
      throw const FormatException('Invalid completion identity or schema.');
    }
    final status = SubmissionStatus.fromJson(raw['submissionStatus']);
    final value = raw['canonicalState'];
    if (status.runSessionId != runSessionId ||
        status.state != RunSessionState.validated ||
        status.reward?.status != SubmissionRewardStatus.finalReward ||
        status.reward?.grantId != runSessionId ||
        value is! Map ||
        value['profileId'] is! String ||
        (value['profileId'] as String).isEmpty ||
        !_validCounter(value['revision']) ||
        value['selection'] is! Map ||
        value['meta'] is! Map ||
        value['progression'] is! Map) {
      throw const FormatException(
        'Completion must contain a settled account snapshot.',
      );
    }
    final progression = value['progression'] as Map;
    final applied = progression['appliedRewardGrantIds'];
    if (!_validCounter(progression['gold']) ||
        applied is! List ||
        !applied.contains(runSessionId)) {
      throw const FormatException(
        'Completion account has not applied this reward.',
      );
    }
    final canonical = OwnershipCanonicalState.fromJson(
      Map<String, dynamic>.from(value),
      fallback: OwnershipCanonicalState(
        profileId: defaultOwnershipProfileId,
        revision: 0,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      ),
    );
    return RunSubmissionResponse(status, canonical: canonical);
  }

  static bool _validCounter(Object? value) =>
      value is int && value >= 0 && value <= 9007199254740991;
}

abstract interface class RunCompletionSource {
  Stream<RunSubmissionResponse> watch({
    required String userId,
    required String runSessionId,
  });
}
