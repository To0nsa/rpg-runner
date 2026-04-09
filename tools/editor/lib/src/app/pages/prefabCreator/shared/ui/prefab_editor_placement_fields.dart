import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';
import '../prefab_form_state.dart';

/// Shared placement/collider fields used by obstacle and platform prefab flows.
class PrefabEditorPlacementFields extends StatelessWidget {
  const PrefabEditorPlacementFields({
    super.key,
    required this.form,
    this.isEnabled = true,
    this.colliderOffsetXLabel = 'Offset X',
    this.colliderOffsetYLabel = 'Offset Y',
    this.colliderWidthLabel = 'Width',
    this.colliderHeightLabel = 'Height',
    this.invalidValuesMessage,
  });

  final PrefabFormState form;
  final bool isEnabled;
  final String colliderOffsetXLabel;
  final String colliderOffsetYLabel;
  final String colliderWidthLabel;
  final String colliderHeightLabel;
  final String? invalidValuesMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: form.anchorXController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Anchor X (px)',
                ),
              ),
            ),
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
            Expanded(
              child: TextField(
                controller: form.anchorYController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Anchor Y (px)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: form.colliderOffsetXController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderOffsetXLabel,
                ),
              ),
            ),
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
            Expanded(
              child: TextField(
                controller: form.colliderOffsetYController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderOffsetYLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: form.colliderWidthController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderWidthLabel,
                ),
              ),
            ),
            const SizedBox(width: PrefabEditorUiTokens.controlGap),
            Expanded(
              child: TextField(
                controller: form.colliderHeightController,
                enabled: isEnabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: colliderHeightLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        if (invalidValuesMessage != null) ...[
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          Text(invalidValuesMessage!),
        ],
      ],
    );
  }
}
