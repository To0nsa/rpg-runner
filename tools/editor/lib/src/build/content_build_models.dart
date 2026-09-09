import 'package:flutter/foundation.dart';

enum ContentBuildPhase {
  idle,
  starting,
  capturing,
  validating,
  checkingOutputs,
  staging,
  committing,
  verifying,
  cancelling,
}

enum GeneratedContentStatus {
  notChecked,
  buildNeeded,
  checking,
  building,
  builtAndVerified,
  failed,
  cancelled,
}

@immutable
final class ContentBuildIssue {
  const ContentBuildIssue({
    required this.code,
    required this.message,
    this.path,
    this.levelId,
  });
  final String code;
  final String message;
  final String? path;
  final String? levelId;
  factory ContentBuildIssue.fromJson(Map<String, dynamic> json) =>
      ContentBuildIssue(
        code: json['code'] as String,
        message: json['message'] as String,
        path: json['path'] as String?,
        levelId: json['levelId'] as String?,
      );
}

@immutable
final class ContentBuildLevel {
  const ContentBuildLevel({
    required this.levelId,
    required this.displayName,
    required this.includeInBuild,
    required this.status,
  });
  final String levelId;
  final String displayName;
  final bool includeInBuild;
  final String status;
  factory ContentBuildLevel.fromJson(Map<String, dynamic> json) =>
      ContentBuildLevel(
        levelId: json['levelId'] as String,
        displayName: json['displayName'] as String,
        includeInBuild: json['includeInBuild'] as bool,
        status: json['status'] as String,
      );
}

/// The generator's authoritative result; process exit alone never proves freshness.
@immutable
final class ContentBuildResult {
  ContentBuildResult({
    required this.outcome,
    required this.dryRun,
    this.inputFingerprint,
    Iterable<ContentBuildLevel> levels = const [],
    Iterable<ContentBuildIssue> issues = const [],
    Iterable<String> changedOutputs = const [],
    Iterable<String> outputs = const [],
    this.outputsCommitted = false,
    this.rollbackComplete = false,
    Iterable<String> transactionFailures = const [],
    this.transactionOutcomeUnknown = false,
  }) : levels = List.unmodifiable(levels),
       issues = List.unmodifiable(issues),
       changedOutputs = List.unmodifiable(changedOutputs),
       outputs = List.unmodifiable(outputs),
       transactionFailures = List.unmodifiable(transactionFailures);
  final String outcome;
  final bool dryRun;
  final String? inputFingerprint;
  final List<ContentBuildLevel> levels;
  final List<ContentBuildIssue> issues;
  final List<String> changedOutputs;
  final List<String> outputs;
  final bool outputsCommitted;
  final bool rollbackComplete;
  final bool transactionOutcomeUnknown;
  final List<String> transactionFailures;
  bool get isVerified => outcome == 'current' || outcome == 'built';
  Iterable<ContentBuildLevel> get includedLevels =>
      levels.where((l) => l.includeInBuild);
  Iterable<ContentBuildLevel> get excludedLevels =>
      levels.where((l) => !l.includeInBuild);

  factory ContentBuildResult.fromJson(Map<String, dynamic> json) {
    if (json['protocolVersion'] != 1 ||
        json['type'] != 'result' ||
        !const {
          'current',
          'drift',
          'built',
          'invalid',
          'cancelled',
          'stale',
          'failed',
        }.contains(json['outcome'])) {
      throw const FormatException('Unsupported content Build report.');
    }
    final result = ContentBuildResult(
      outcome: json['outcome'] as String,
      dryRun: json['dryRun'] as bool,
      inputFingerprint: json['inputFingerprint'] as String?,
      levels: (json['levels'] as List).map(
        (v) => ContentBuildLevel.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      issues: (json['issues'] as List).map(
        (v) => ContentBuildIssue.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      changedOutputs: (json['changes'] as List).map(
        (v) => (v as Map)['path'] as String,
      ),
      outputs: (json['outputs'] as List).cast<String>(),
      outputsCommitted: json['outputsCommitted'] as bool,
      rollbackComplete: json['rollbackComplete'] as bool,
      transactionFailures: (json['transactionFailures'] as List).cast<String>(),
    );
    if (result.isVerified &&
        (!RegExp(r'^[0-9a-f]{64}$').hasMatch(result.inputFingerprint ?? '') ||
            result.issues.isNotEmpty ||
            result.transactionFailures.isNotEmpty ||
            result.rollbackComplete ||
            (result.dryRun
                ? result.outcome != 'current' || result.outputsCommitted
                : result.outcome != 'built' || !result.outputsCommitted))) {
      throw const FormatException(
        'Verified Build report has no trustworthy input identity.',
      );
    }
    return result;
  }
}
