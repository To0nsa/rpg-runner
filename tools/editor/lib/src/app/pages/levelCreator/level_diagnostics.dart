import 'package:flutter/material.dart';

import '../../../domain/authoring_types.dart';

/// Full operation-specific diagnostic list; technical evidence stays expandable.
class LevelDiagnostics extends StatelessWidget {
  const LevelDiagnostics({
    super.key,
    required this.issues,
    required this.onOpen,
    this.repairLabel,
    this.onRepair,
  });

  final List<ValidationIssue> issues;
  final ValueChanged<ValidationIssue> onOpen;
  final String? Function(ValidationIssue)? repairLabel;
  final ValueChanged<ValidationIssue>? onRepair;

  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: issues.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final issue = issues[index];
      final blockers = AuthoringOperation.values
          .where(issue.blocks)
          .map(
            (operation) => switch (operation) {
              AuthoringOperation.save => 'Save',
              AuthoringOperation.play => 'Play',
              AuthoringOperation.build => 'Build',
            },
          )
          .join(', ');
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.severity == ValidationSeverity.error
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue.message)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                blockers.isEmpty ? 'Suggestion' : 'Blocks $blockers',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => onOpen(issue),
                    child: const Text('Open'),
                  ),
                  if (repairLabel?.call(issue) case final String label)
                    TextButton(
                      onPressed: onRepair == null
                          ? null
                          : () => onRepair!(issue),
                      child: Text(label),
                    ),
                  Expanded(
                    child: ExpansionTile(
                      title: const Text('Details'),
                      children: [
                        SelectableText(issue.code),
                        if (issue.sourcePath != null)
                          SelectableText(issue.sourcePath!),
                        if (issue.ownerKey != null)
                          SelectableText(issue.ownerKey!),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
