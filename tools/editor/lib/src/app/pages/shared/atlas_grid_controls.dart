import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../atlas/atlas_grid.dart';
import 'editor_ui_tokens.dart';

/// Editable, session-only grid settings shared by atlas pickers.
class AtlasGridControls extends StatefulWidget {
  const AtlasGridControls({
    super.key,
    required this.settings,
    required this.onChanged,
    this.keyPrefix = 'atlas_grid',
  });

  final AtlasGridSettings settings;
  final ValueChanged<AtlasGridSettings> onChanged;
  final String keyPrefix;

  @override
  State<AtlasGridControls> createState() => _AtlasGridControlsState();
}

class _AtlasGridControlsState extends State<AtlasGridControls> {
  late final List<TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    _sync(widget.settings);
  }

  @override
  void didUpdateWidget(covariant AtlasGridControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) _sync(widget.settings);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _field(0, 'Cell W', 'cell_width'),
          const SizedBox(width: EditorUiTokens.controlGap),
          _field(1, 'Cell H', 'cell_height'),
        ],
      ),
      const SizedBox(height: EditorUiTokens.controlGap),
      Row(
        children: [
          _field(2, 'Origin X', 'origin_x'),
          const SizedBox(width: EditorUiTokens.controlGap),
          _field(3, 'Origin Y', 'origin_y'),
        ],
      ),
      const SizedBox(height: EditorUiTokens.controlGap),
      Row(
        children: [
          _field(4, 'Gutter X', 'gutter_x'),
          const SizedBox(width: EditorUiTokens.controlGap),
          _field(5, 'Gutter Y', 'gutter_y'),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: EditorUiTokens.controlGap),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );

  Widget _field(int index, String label, String suffix) => Expanded(
    child: TextField(
      key: ValueKey<String>('${widget.keyPrefix}_$suffix'),
      controller: _controllers[index],
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
      ),
      onChanged: (_) => _emitIfValid(),
    ),
  );

  void _emitIfValid() {
    final values = _controllers
        .map((controller) => int.tryParse(controller.text.trim()))
        .toList(growable: false);
    String? error;
    if (values.any((value) => value == null)) {
      error = 'Every grid value must be a whole number.';
    } else if (values[0]! <= 0 || values[1]! <= 0) {
      error = 'Cell width and height must be positive.';
    }
    if (_error != error) setState(() => _error = error);
    if (error != null) return;
    widget.onChanged(
      AtlasGridSettings(
        cellWidth: values[0]!,
        cellHeight: values[1]!,
        originX: values[2]!,
        originY: values[3]!,
        gutterX: values[4]!,
        gutterY: values[5]!,
      ),
    );
  }

  void _sync(AtlasGridSettings settings) {
    final values = <int>[
      settings.cellWidth,
      settings.cellHeight,
      settings.originX,
      settings.originY,
      settings.gutterX,
      settings.gutterY,
    ];
    for (var index = 0; index < values.length; index += 1) {
      final text = values[index].toString();
      if (_controllers[index].text != text) _controllers[index].text = text;
    }
    _error = null;
  }
}
