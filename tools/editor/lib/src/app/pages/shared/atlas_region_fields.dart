import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Manual source-region fields shared by atlas authoring workflows.
class AtlasRegionFields extends StatelessWidget {
  const AtlasRegionFields({
    super.key,
    required this.xController,
    required this.yController,
    required this.widthController,
    required this.heightController,
    required this.onChanged,
    this.keyPrefix = 'atlas_selection',
  });

  final TextEditingController xController;
  final TextEditingController yController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final VoidCallback onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          _field(xController, 'Selection X', 'x'),
          const SizedBox(width: EditorUiTokens.controlGap),
          _field(yController, 'Selection Y', 'y'),
        ],
      ),
      const SizedBox(height: EditorUiTokens.controlGap),
      Row(
        children: [
          _field(widthController, 'Selection W', 'w'),
          const SizedBox(width: EditorUiTokens.controlGap),
          _field(heightController, 'Selection H', 'h'),
        ],
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String suffix,
  ) => Expanded(
    child: TextField(
      key: ValueKey<String>('${keyPrefix}_${suffix}_field'),
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onChanged(),
    ),
  );
}
