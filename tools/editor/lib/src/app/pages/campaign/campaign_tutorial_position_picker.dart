import 'package:flutter/material.dart';

/// Chunk-local trigger authoring over captured composition; never edits geometry.
class CampaignTutorialPositionPicker extends StatelessWidget {
  const CampaignTutorialPositionPicker({
    super.key,
    required this.chunks,
    required this.chunkId,
    required this.x,
    required this.onChunkChanged,
    required this.onXChanged,
    this.previewBuilder,
  });

  final List<String> chunks;
  final String? chunkId;
  final double x;
  final ValueChanged<String> onChunkChanged;
  final ValueChanged<double> onXChanged;
  final Widget Function(String)? previewBuilder;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey(chunkId),
        initialValue: chunks.contains(chunkId) ? chunkId : null,
        decoration: const InputDecoration(labelText: 'Trigger mission chunk'),
        items: [
          for (final id in chunks) DropdownMenuItem(value: id, child: Text(id)),
        ],
        validator: (value) =>
            chunks.contains(value) ? null : 'Select an existing mission chunk.',
        onChanged: (value) {
          if (value != null) onChunkChanged(value);
        },
      ),
      TextFormField(
        initialValue: x.toString(),
        decoration: const InputDecoration(
          labelText: 'Trigger X (world units)',
          helperText: 'Within the chunk, from 0 to 600. Waits for dry ground and an available Dash.',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (text) {
          final value = double.tryParse(text ?? '');
          return value != null && value.isFinite && value >= 0 && value <= 600
              ? null
              : 'Enter a position from 0 to 600.';
        },
        onChanged: (text) {
          final value = double.tryParse(text);
          if (value != null && value.isFinite && value >= 0 && value <= 600) {
            onXChanged(value);
          }
        },
      ),
      if (chunkId != null && previewBuilder != null)
        AspectRatio(
          aspectRatio: 600 / 270,
          child: Stack(
            fit: StackFit.expand,
            children: [
              previewBuilder!(chunkId!),
              IgnorePointer(
                child: CustomPaint(
                  painter: _TriggerPainter(
                    x,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _TriggerPainter extends CustomPainter {
  const _TriggerPainter(this.x, this.color);
  final double x;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final dx = size.width * x / 600;
    canvas.drawLine(
      Offset(dx, 0),
      Offset(dx, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TriggerPainter oldDelegate) =>
      oldDelegate.x != x || oldDelegate.color != color;
}
