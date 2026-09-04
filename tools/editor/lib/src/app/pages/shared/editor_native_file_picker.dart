import 'package:file_selector/file_selector.dart';

typedef EditorNativeFilePicker = Future<String?> Function({
  required String initialDirectory,
});

/// Opens the platform file dialog with one domain-owned file-type policy.
Future<String?> pickEditorFilePath({
  required String initialDirectory,
  required String typeLabel,
  required List<String> extensions,
}) async {
  final file = await openFile(
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(label: typeLabel, extensions: extensions),
    ],
    initialDirectory: initialDirectory,
    confirmButtonText: 'Select',
  );
  return file?.path;
}
