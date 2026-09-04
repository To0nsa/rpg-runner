import 'package:flutter/material.dart';

import '../../../domain/authoring_types.dart';

/// Standard bordered pane used by the Level Creator columns.
class LevelPane extends StatelessWidget {
  const LevelPane({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x22101820),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x334A6074)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// Read-only presentation of one Level validation issue.
class LevelValidationIssueRow extends StatelessWidget {
  const LevelValidationIssueRow({super.key, required this.issue});

  final ValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final color = switch (issue.severity) {
      ValidationSeverity.error => Colors.red.shade300,
      ValidationSeverity.warning => Colors.orange.shade300,
      ValidationSeverity.info => Colors.blue.shade300,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '[${issue.code}] ${issue.message}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}

/// Passive route-level load or export error banner.
class LevelErrorBanner extends StatelessWidget {
  const LevelErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: MaterialBanner(
      content: Text(message),
      actions: const [SizedBox.shrink()],
    ),
  );
}
