import 'loadout_issue.dart';

/// Result of a full loadout validation pass.
class LoadoutValidationResult {
  const LoadoutValidationResult({
    required this.isValid,
    this.issues = const [],
  });

  /// A completely valid result with no issues.
  static const LoadoutValidationResult valid = LoadoutValidationResult(isValid: true);

  /// Creates an invalid result with a list of issues.
  factory LoadoutValidationResult.invalid(List<LoadoutIssue> issues) =>
      LoadoutValidationResult(isValid: false, issues: issues);

  /// Whether the loadout is considered valid and runnable.
  final bool isValid;

  /// List of issues found during validation.
  final List<LoadoutIssue> issues;
}
