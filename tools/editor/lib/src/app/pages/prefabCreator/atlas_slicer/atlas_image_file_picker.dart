import '../../shared/editor_native_file_picker.dart';

typedef AtlasImageFilePicker = EditorNativeFilePicker;

/// Opens the platform file dialog for one PNG atlas or tileset image.
Future<String?> pickAtlasImageFilePath({required String initialDirectory}) =>
    pickEditorFilePath(
      initialDirectory: initialDirectory,
      typeLabel: 'Atlas and tileset PNG images',
      extensions: const <String>['png'],
    );
