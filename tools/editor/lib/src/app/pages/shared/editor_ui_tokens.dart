import 'package:flutter/widgets.dart';

/// Canonical spacing and sizing tokens for editor workspace composition.
///
/// Route widgets use these values instead of defining local panel geometry, so
/// authoring surfaces remain visually consistent as domains are added.
final class EditorUiTokens {
  EditorUiTokens._();

  static const double panelGap = 12;
  static const double workspacePadding = 16;
  static const double panelPadding = 12;
  static const double panelRadius = 12;
  static const double sectionGap = 12;
  static const double controlGap = 8;
  static const double rowPreviewGap = 12;
  static const double rowTrailingGap = 8;
  static const double rowTitleGap = 4;
  static const double rowMetadataGap = 2;

  static const EdgeInsets workspaceInsets = EdgeInsets.all(workspacePadding);
  static const EdgeInsets panelInsets = EdgeInsets.all(panelPadding);
}
