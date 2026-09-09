import 'package:flutter/material.dart';

import '../../../build/content_build_service.dart';

/// Shell-neutral Build presentation; Save and repair navigation stay with callers.
final class ContentBuildDialog extends StatelessWidget {
  const ContentBuildDialog({
    super.key,
    required this.controller,
    required this.onClose,
    this.onBuild,
    this.onCheck,
    this.onOpenIssue,
    this.onOpenLevel,
    this.onAddContent,
    this.onExcludeLevel,
    this.onRestoreLevel,
  });
  final ContentBuildService controller;
  final VoidCallback onClose;
  final VoidCallback? onBuild;
  final VoidCallback? onCheck;
  final ValueChanged<ContentBuildIssue>? onOpenIssue;
  final ValueChanged<ContentBuildLevel>? onOpenLevel;
  final ValueChanged<ContentBuildLevel>? onAddContent;
  final ValueChanged<ContentBuildLevel>? onExcludeLevel;
  final ValueChanged<ContentBuildLevel>? onRestoreLevel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => PopScope(
      canPop: !controller.isRunning,
      child: AlertDialog(
        key: const ValueKey('content_build_dialog'),
        title: const Text('Build game content'),
        content: SizedBox(
          width: 660,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusMessage(controller),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (controller.isRunning) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_phaseMessage(controller.phase)),
                ],
                if (controller.hasUnsavedAuthoring)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Save authoring changes before building game content.',
                    ),
                  ),
                if (controller.result case final result?) ...[
                  const SizedBox(height: 16),
                  if (result.outputsCommitted && !result.isVerified)
                    const Text(
                      'Generated outputs changed, but Build did not finish cleanly. Review the report and check content before continuing.',
                    ),
                  if (result.transactionOutcomeUnknown)
                    const Text(
                      'The generator did not report a final transaction result. Check generated content before continuing.',
                    ),
                  if (result.rollbackComplete)
                    const Text(
                      'Output replacement was rolled back; previous generated files were restored.',
                    ),
                  for (final issue in result.issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.message),
                          Text(
                            [
                              issue.code,
                              if (issue.path != null) issue.path!,
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (onOpenIssue != null)
                            TextButton(
                              onPressed: controller.isRunning
                                  ? null
                                  : () => onOpenIssue!(issue),
                              child: const Text('Open source'),
                            ),
                        ],
                      ),
                    ),
                  if (result.transactionFailures.isNotEmpty) ...[
                    const Text(
                      'Transaction cleanup or recovery needs attention:',
                    ),
                    for (final failure in result.transactionFailures)
                      Text(failure),
                  ],
                  if (result.levels.isNotEmpty) ...[
                    _levelList(
                      context,
                      'Included in game build',
                      result.includedLevels.toList(),
                    ),
                    _levelList(
                      context,
                      'Excluded from game build',
                      result.excludedLevels.toList(),
                    ),
                  ],
                  if (result.changedOutputs.isNotEmpty)
                    ExpansionTile(
                      title: Text(
                        '${result.changedOutputs.length} generated output change(s)',
                      ),
                      children: [
                        for (final output in result.changedOutputs)
                          ListTile(dense: true, title: Text(output)),
                      ],
                    ),
                  if (result.isVerified)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Restart or rebuild running game/editor applications to load changed generated constants. Authored Play uses the current authoring snapshot directly.',
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'This builds saved content for the whole repository. App and replay validator builds must use compatible content; online level and board configuration is managed separately.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (controller.isRunning)
            TextButton(
              key: const ValueKey('content_build_cancel'),
              onPressed: controller.canCancel ? controller.cancel : null,
              child: Text(
                controller.isFinishingSafely
                    ? 'Finishing safely'
                    : 'Cancel Build',
              ),
            ),
          if (!controller.isRunning && onCheck != null)
            TextButton(
              key: const ValueKey('content_build_check'),
              onPressed: onCheck,
              child: const Text('Check freshness'),
            ),
          if (!controller.isRunning && onBuild != null)
            FilledButton(
              key: const ValueKey('content_build_start'),
              onPressed: onBuild,
              child: const Text('Build game content'),
            ),
          TextButton(
            key: const ValueKey('content_build_close'),
            onPressed: controller.isRunning ? null : onClose,
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );

  Widget _levelList(
    BuildContext context,
    String title,
    List<ContentBuildLevel> levels,
  ) => ExpansionTile(
    initiallyExpanded: levels.isNotEmpty,
    title: Text('$title (${levels.length})'),
    children: [
      for (final level in levels)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level.displayName),
              Text(
                '${level.levelId} • ${level.status}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 4,
                children: [
                  if (onOpenLevel != null)
                    TextButton(
                      onPressed: controller.isRunning
                          ? null
                          : () => onOpenLevel!(level),
                      child: const Text('Open'),
                    ),
                  if (!level.includeInBuild && onRestoreLevel != null)
                    TextButton(
                      onPressed: controller.isRunning
                          ? null
                          : () => onRestoreLevel!(level),
                      child: const Text('Restore to game build'),
                    ),
                  if (level.includeInBuild &&
                      controller.result?.isVerified == false) ...[
                    if (onAddContent != null)
                      TextButton(
                        onPressed: controller.isRunning
                            ? null
                            : () => onAddContent!(level),
                        child: const Text('Add content'),
                      ),
                    if (onExcludeLevel != null)
                      TextButton(
                        onPressed: controller.isRunning
                            ? null
                            : () => onExcludeLevel!(level),
                        child: const Text('Exclude from game build'),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
    ],
  );
}

String _statusMessage(ContentBuildService service) => service.isFinishingSafely
    ? 'Finishing safely'
    : switch (service.status) {
        GeneratedContentStatus.notChecked =>
          'Generated content has not been checked.',
        GeneratedContentStatus.buildNeeded => 'Build needed',
        GeneratedContentStatus.checking => 'Checking saved content',
        GeneratedContentStatus.building => 'Building saved game content',
        GeneratedContentStatus.builtAndVerified => 'Built and verified',
        GeneratedContentStatus.failed => 'Build failed',
        GeneratedContentStatus.cancelled =>
          'Build cancelled before output replacement',
      };

String _phaseMessage(ContentBuildPhase phase) => switch (phase) {
  ContentBuildPhase.idle => '',
  ContentBuildPhase.starting => 'Starting the repository generator…',
  ContentBuildPhase.capturing => 'Capturing saved sources and images…',
  ContentBuildPhase.validating => 'Validating every authored source…',
  ContentBuildPhase.checkingOutputs => 'Comparing generated outputs…',
  ContentBuildPhase.staging => 'Staging complete output files…',
  ContentBuildPhase.committing =>
    'Replacing output files. The transaction will finish or roll back safely.',
  ContentBuildPhase.verifying =>
    'Verifying exact outputs and source freshness…',
  ContentBuildPhase.cancelling => 'Cancelling before output replacement…',
};
