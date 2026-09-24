import 'package:flutter/material.dart';

/// Uses the same authored integer depth scale as placed prefabs.
class ChunkTrapDepthField extends StatelessWidget {
  const ChunkTrapDepthField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(signed: true),
    decoration: InputDecoration(
      labelText: 'Z-index',
      helperText: 'Higher values draw in front. Stays fixed during animation.',
      helperMaxLines: 2,
      border: const OutlineInputBorder(),
      errorText: int.tryParse(controller.text.trim()) == null
          ? 'Use a whole-number Z-index.'
          : null,
    ),
    onChanged: (_) => onChanged(),
  );
}
