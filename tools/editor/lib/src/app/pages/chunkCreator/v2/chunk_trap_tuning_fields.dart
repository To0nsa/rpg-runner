import 'package:flutter/material.dart';

import '../../../../chunks/chunk_trap_tuning_input.dart';

/// Shared display-unit controls for new placements and the inline edit buffer.
class ChunkTrapTuningFields extends StatelessWidget {
  const ChunkTrapTuningFields({
    super.key,
    required this.keyPrefix,
    required this.damage,
    required this.windup,
    required this.enabled,
    required this.onChanged,
    required this.onReset,
  });

  final String keyPrefix;
  final TextEditingController damage, windup;
  final bool enabled;
  final VoidCallback onChanged, onReset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('${keyPrefix}_damage'),
              controller: damage,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Damage on hit (HP)',
                border: const OutlineInputBorder(),
                errorText: parseTrapDamage100(damage.text) == null
                    ? 'Use 0.01–1000 HP, up to 2 decimals.'
                    : null,
                errorMaxLines: 2,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey('${keyPrefix}_windup'),
              controller: windup,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Seconds before damage',
                border: const OutlineInputBorder(),
                errorText: parseTrapWindupMs(windup.text) == null
                    ? 'Use 0–30 seconds, up to 3 decimals.'
                    : null,
                errorMaxLines: 2,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: ValueKey('${keyPrefix}_reset'),
          onPressed: enabled ? onReset : null,
          child: const Text('Reset to defaults'),
        ),
      ),
    ],
  );
}
