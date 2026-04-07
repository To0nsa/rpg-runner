part of '../entities_editor_page.dart';

/// Bottom-band diagnostics/result panels for the entities route.
///
/// These widgets are read-only views over controller/session state and local
/// panel selections (`_selectedDiffPath`, `_selectedArtifactTitle`).
extension _EntitiesEditorStatusPanels on _EntitiesEditorPageState {
  Widget _buildValidationPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validation', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: widget.controller.issues.isEmpty
                  ? const Text('No validation issues.')
                  : ListView.builder(
                      itemCount: widget.controller.issues.length,
                      itemBuilder: (context, index) {
                        final issue = widget.controller.issues[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _iconForSeverity(issue.severity),
                            color: _colorForSeverity(issue.severity),
                          ),
                          title: Text(issue.message),
                          subtitle: issue.sourcePath == null
                              ? null
                              : Text(issue.sourcePath!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDiffPanel() {
    final pendingChanges = widget.controller.pendingChanges;
    final diffError = widget.controller.pendingChangesError;
    final selectedDiff = _selectedDiff(pendingChanges);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending File Diff',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'entries: ${pendingChanges.changedItemIds.length} '
              'files: ${pendingChanges.fileDiffs.length}',
            ),
            if (pendingChanges.fileDiffs.length > 1) ...[
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedDiff?.relativePath,
                items: [
                  for (final fileDiff in pendingChanges.fileDiffs)
                    DropdownMenuItem<String>(
                      value: fileDiff.relativePath,
                      child: Text(
                        '${fileDiff.relativePath} (${fileDiff.editCount})',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _updateState(() {
                    _selectedDiffPath = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: diffError != null
                  ? SelectableText(diffError)
                  : selectedDiff == null
                  ? const Text('No pending file changes.')
                  : SingleChildScrollView(
                      child: SelectableText(
                        selectedDiff.unifiedDiff,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyResultPanel() {
    final exportResult = widget.controller.lastExportResult;
    final exportError = widget.controller.exportError;
    final artifact = _selectedArtifact(exportResult);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply Result', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (exportError != null) ...[
              SelectableText(
                exportError,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
            ],
            if (exportResult != null) ...[
              Text('files written: ${exportResult.applied ? 'yes' : 'no'}'),
              if (exportResult.artifacts.length > 1) ...[
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: artifact?.title,
                  items: [
                    for (final item in exportResult.artifacts)
                      DropdownMenuItem<String>(
                        value: item.title,
                        child: Text(item.title),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _updateState(() {
                      _selectedArtifactTitle = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
            Expanded(
              child: artifact == null
                  ? const Text('No apply result yet.')
                  : SingleChildScrollView(
                      child: SelectableText(artifact.content),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForSeverity(ValidationSeverity severity) {
    // Keep severity icon mapping stable so issue rows remain quickly scannable.
    switch (severity) {
      case ValidationSeverity.info:
        return Icons.info_outline;
      case ValidationSeverity.warning:
        return Icons.warning_amber_rounded;
      case ValidationSeverity.error:
        return Icons.error_outline;
    }
  }

  Color _colorForSeverity(ValidationSeverity severity) {
    // Color semantics mirror icon severity mapping above.
    switch (severity) {
      case ValidationSeverity.info:
        return Colors.lightBlueAccent;
      case ValidationSeverity.warning:
        return Colors.amberAccent;
      case ValidationSeverity.error:
        return Colors.redAccent;
    }
  }
}
