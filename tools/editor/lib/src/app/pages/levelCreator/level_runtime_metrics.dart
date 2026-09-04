import 'package:flutter/material.dart';

/// Compact editor for the runtime metrics stored on the active Level.
///
/// The page owns the controllers and applies their values. This widget only
/// presents the fields, including the two values that are derived and locked.
class LevelRuntimeMetrics extends StatelessWidget {
  const LevelRuntimeMetrics({
    super.key,
    required this.cameraCenterYController,
    required this.groundTopYController,
    required this.earlyPatternChunksController,
    required this.easyPatternChunksController,
    required this.normalPatternChunksController,
    required this.noEnemyChunksController,
  });

  final TextEditingController cameraCenterYController;
  final TextEditingController groundTopYController;
  final TextEditingController earlyPatternChunksController;
  final TextEditingController easyPatternChunksController;
  final TextEditingController normalPatternChunksController;
  final TextEditingController noEnemyChunksController;

  @override
  Widget build(BuildContext context) {
    final lockedFillColor = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.32);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _RuntimeMetricField(
            controller: cameraCenterYController,
            label: 'cameraCenterY',
            fillColor: lockedFillColor,
            readOnly: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(width: 8),
          _RuntimeMetricField(
            controller: groundTopYController,
            label: 'groundTopY',
            fillColor: lockedFillColor,
            readOnly: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(width: 8),
          _RuntimeMetricField(
            controller: earlyPatternChunksController,
            label: 'earlyPatternChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 8),
          _RuntimeMetricField(
            controller: easyPatternChunksController,
            label: 'easyPatternChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 8),
          _RuntimeMetricField(
            controller: normalPatternChunksController,
            label: 'normalPatternChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 8),
          _RuntimeMetricField(
            controller: noEnemyChunksController,
            label: 'noEnemyChunks',
            fillColor: lockedFillColor,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

class _RuntimeMetricField extends StatelessWidget {
  const _RuntimeMetricField({
    required this.controller,
    required this.label,
    required this.fillColor,
    this.readOnly = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final Color fillColor;
  final bool readOnly;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      style: readOnly
          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? fillColor : null,
        suffixIcon: readOnly ? const Icon(Icons.lock_outline) : null,
      ),
      keyboardType: keyboardType,
    ),
  );
}
