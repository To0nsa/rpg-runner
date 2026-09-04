import '../shared/editor_native_file_picker.dart';

typedef ParallaxAssetFilePicker = EditorNativeFilePicker;

/// Opens the platform file dialog for one parallax image.
///
/// The page converts the returned absolute path into an authored
/// workspace-relative path and rejects selections outside the workspace.
Future<String?> pickParallaxAssetFilePath({required String initialDirectory}) =>
    pickEditorFilePath(
      initialDirectory: initialDirectory,
      typeLabel: 'Parallax images',
      extensions: const <String>['png', 'jpg', 'jpeg', 'webp'],
    );
