import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../domain/authoring_intent_reconciliation.dart';

/// Explicit field choices for a domain-owned three-way recovery plan.
Future<Map<String, AuthoringConflictChoice>?> showAuthoringConflictDialog(
  BuildContext context,
  AuthoringReapplyPlan plan,
) => showDialog<Map<String, AuthoringConflictChoice>>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _ConflictDialog(plan: plan),
);

class _ConflictDialog extends StatefulWidget {
  const _ConflictDialog({required this.plan});
  final AuthoringReapplyPlan plan;

  @override
  State<_ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<_ConflictDialog> {
  final Map<String, AuthoringConflictChoice> _choices = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review and reapply changes'),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current saved content is reloaded before applying your edits. '
              'Choose how to resolve fields that changed in both versions.',
            ),
            if (widget.plan.conflicts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Your edits do not conflict with the saved content.',
                ),
              ),
            for (final conflict in widget.plan.conflicts)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conflict.path,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SelectableText(
                      'Saved: ${jsonEncode(conflict.savedValue)}\n'
                      'Your edit: ${jsonEncode(conflict.intendedValue)}',
                    ),
                    if (!conflict.canUseIntended)
                      const Text(
                        'This identity changed externally. Keep the saved identity; '
                        'the retained edit remains available until you confirm.',
                      ),
                    DropdownButton<AuthoringConflictChoice>(
                      value: _choices[conflict.path],
                      hint: const Text('Choose a value'),
                      items: [
                        const DropdownMenuItem(
                          value: AuthoringConflictChoice.saved,
                          child: Text('Use saved value'),
                        ),
                        if (conflict.canUseIntended)
                          const DropdownMenuItem(
                            value: AuthoringConflictChoice.intended,
                            child: Text('Use my edit'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _choices[conflict.path] = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Keep editing'),
      ),
      FilledButton(
        onPressed:
            widget.plan.conflicts.every(
              (item) => _choices.containsKey(item.path),
            )
            ? () =>
                  Navigator.of(context)
                      .pop(Map<String, AuthoringConflictChoice>.of(_choices))
            : null,
        child: const Text('Reapply edits'),
      ),
    ],
  );
}
