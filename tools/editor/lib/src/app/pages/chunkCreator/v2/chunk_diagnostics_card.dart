import 'package:flutter/material.dart';

import '../../../../domain/authoring_types.dart';
import '../../shared/editor_panel_card.dart';

/// Read-only summary and details for current Chunk validation issues.
class ChunkDiagnosticsCard extends StatelessWidget {
  const ChunkDiagnosticsCard({super.key, required this.issues});

  final List<ValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final errorCount = issues
        .where((issue) => issue.severity == ValidationSeverity.error)
        .length;
    final warningCount = issues
        .where((issue) => issue.severity == ValidationSeverity.warning)
        .length;
    final infoCount = issues.length - errorCount - warningCount;
    final description = issues.isEmpty
        ? 'No issues in the current chunk document.'
        : '${issues.length} total · $errorCount error(s) · '
              '$warningCount warning(s) · $infoCount info';
    return EditorPanelCard(
      key: const ValueKey<String>('chunk_diagnostics_card'),
      title: 'Diagnostics',
      description: description,
      collapsible: true,
      initiallyExpanded: false,
      expansionKey: const ValueKey<String>('chunk_diagnostics_card_toggle'),
      child: Column(
        key: const ValueKey<String>('chunk_diagnostics_list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (issues.isEmpty)
            const Text('No validation issues.')
          else
            for (final (index, issue) in issues.indexed)
              ListTile(
                key: ValueKey<String>(
                  'chunk_diagnostic_${index}_${issue.code}',
                ),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _diagnosticIcon(issue.severity),
                  color: _diagnosticColor(issue.severity),
                ),
                title: Text(issue.code),
                subtitle: Text(
                  [issue.message, ?_diagnosticContext(issue)].join('\n'),
                ),
              ),
        ],
      ),
    );
  }
}

IconData _diagnosticIcon(ValidationSeverity severity) => switch (severity) {
  ValidationSeverity.error => Icons.error_outline,
  ValidationSeverity.warning => Icons.warning_amber_outlined,
  ValidationSeverity.info => Icons.info_outline,
};

Color _diagnosticColor(ValidationSeverity severity) => switch (severity) {
  ValidationSeverity.error => const Color(0xFFFF7F7F),
  ValidationSeverity.warning => const Color(0xFFFFD166),
  ValidationSeverity.info => const Color(0xFF7DD3FC),
};

String? _diagnosticContext(ValidationIssue issue) {
  final sourcePath = issue.sourcePath?.trim();
  final ownerKey = issue.ownerKey?.trim();
  final placementKey = issue.placementKey?.trim();
  final shapeId = issue.shapeId?.trim();
  final parts = <String>[
    if (sourcePath != null && sourcePath.isNotEmpty) sourcePath,
    if (ownerKey != null && ownerKey.isNotEmpty) 'owner $ownerKey',
    if (placementKey != null && placementKey.isNotEmpty)
      'placement $placementKey',
    if (shapeId != null && shapeId.isNotEmpty) 'shape $shapeId',
    if (issue.elementIndex case final elementIndex?) 'element $elementIndex',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
