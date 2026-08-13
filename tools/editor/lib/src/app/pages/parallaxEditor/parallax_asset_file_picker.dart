import 'package:file_selector/file_selector.dart';

typedef ParallaxAssetFilePicker =
    Future<String?> Function({required String initialDirectory});

const XTypeGroup _parallaxImageTypeGroup = XTypeGroup(
  label: 'Parallax images',
  extensions: <String>['png', 'jpg', 'jpeg', 'webp'],
);

/// Opens the platform file dialog for one parallax image.
///
/// The page converts the returned absolute path into an authored
/// workspace-relative path and rejects selections outside the workspace.
Future<String?> pickParallaxAssetFilePath({
  required String initialDirectory,
}) async {
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[_parallaxImageTypeGroup],
    initialDirectory: initialDirectory,
    confirmButtonText: 'Select',
  );
  return file?.path;
}
