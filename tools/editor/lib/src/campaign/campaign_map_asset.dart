import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../workspace/editor_workspace.dart';

/// Reads artwork metadata without importing external files or changing sources.
/// The same portable path policy is enforced by the shared source decoder.
Future<CampaignMapSource> readCampaignMapAsset(
  EditorWorkspace workspace,
  String selectedPath,
) async {
  final relative = p
      .relative(p.absolute(selectedPath), from: workspace.rootPath)
      .replaceAll('\\', '/');
  CampaignMapSource.decode({'assetPath': relative, 'width': 1, 'height': 1});
  final file = File(workspace.resolve(relative));
  final canonical = await file.resolveSymbolicLinks();
  if (!p.isWithin(workspace.rootPath, canonical)) {
    throw const FormatException(
      'Choose an image inside the current workspace.',
    );
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return CampaignMapSource.decode({
        'assetPath': relative,
        'width': descriptor.width,
        'height': descriptor.height,
      });
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
