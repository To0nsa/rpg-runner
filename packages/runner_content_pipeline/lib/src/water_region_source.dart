import 'package:runner_core/terrain/water_region.dart';

/// Decodes the optional Chunk-v2 water collection with no coercion or I/O.
///
/// An absent collection is empty. Present records must be strictly ID-ordered,
/// use whole pixels, and fit the closed chunk bounds. Adjacent pools are valid;
/// overlapping pools are rejected to keep rendering and immersion unambiguous.
List<WaterRegionData> decodeWaterRegions(
  Object? value, {
  required String sourcePath,
  required int chunkWidth,
  required int chunkHeight,
}) {
  if (value is! List) throw FormatException('$sourcePath must be an array.');
  final regions = <WaterRegionData>[];
  for (var index = 0; index < value.length; index++) {
    final path = '$sourcePath[$index]';
    final json = value[index];
    const fields = {'id', 'x', 'y', 'width', 'height', 'materialKey'};
    if (json is! Map<String, dynamic> ||
        json.length != fields.length ||
        !json.keys.every(fields.contains)) {
      throw FormatException('$path must contain exactly ${fields.join(', ')}.');
    }
    if (json['id'] is! String ||
        json['materialKey'] is! String ||
        !['x', 'y', 'width', 'height'].every((key) => json[key] is int)) {
      throw FormatException(
        '$path requires string keys and integer pixel bounds.',
      );
    }
    final WaterRegionData region;
    try {
      region = WaterRegionData(
        id: json['id'] as String,
        x: json['x'] as int,
        y: json['y'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
        materialKey: json['materialKey'] as String,
      );
    } on ArgumentError catch (error) {
      throw FormatException('$path: ${error.message}');
    }
    regions.add(region);
  }
  try {
    validateWaterRegionCollection(
      regions,
      chunkWidth: chunkWidth,
      chunkHeight: chunkHeight,
    );
  } on ArgumentError catch (error) {
    throw FormatException('$sourcePath: ${error.message}');
  }
  return List.unmodifiable(regions);
}
