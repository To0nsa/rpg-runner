import 'package:file_selector/file_selector.dart';

/// Picks one workspace directory path using the platform file-selection UI.
///
/// Returns `null` when the user cancels the picker.
Future<String?> pickWorkspaceDirectoryPath() {
  return getDirectoryPath();
}
