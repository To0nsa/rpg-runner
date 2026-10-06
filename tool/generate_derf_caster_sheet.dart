import 'dart:io';

import 'package:image/image.dart' as image;

/// Pads original cultist cells to the twisted sheet's canvas without rescaling.
/// Run from the repository root; --dry-run checks the checked-in runtime sheet.
void main(List<String> arguments) {
  if (arguments.any((argument) => argument != '--dry-run')) {
    throw ArgumentError('Only --dry-run is supported.');
  }
  const directory = 'assets/images/entities/enemies/derf';
  final original = image.decodePng(
    File('$directory/derf.png').readAsBytesSync(),
  )!;
  if (original.width != 540 || original.height != 420) {
    throw StateError('Expected the original 12-column, 10-row cultist sheet.');
  }
  final padded = image.Image(width: 1092, height: 420, numChannels: 4);
  for (var row = 0; row < 10; row++) {
    for (var column = 0; column < 12; column++) {
      for (var y = 0; y < 42; y++) {
        for (var x = 0; x < 45; x++) {
          final pixel = original.getPixel(column * 45 + x, row * 42 + y);
          padded.setPixelRgba(
            column * 91 + 44 + x,
            row * 42 + y,
            pixel.r,
            pixel.g,
            pixel.b,
            pixel.a,
          );
        }
      }
    }
  }
  final output = File('$directory/caster_sheet.png');
  final bytes = image.encodePng(padded);
  if (arguments.contains('--dry-run')) {
    if (!output.existsSync() || !_equal(output.readAsBytesSync(), bytes)) {
      stderr.writeln('Derf caster sheet is stale; regenerate it.');
      exitCode = 1;
    }
    return;
  }
  output.writeAsBytesSync(bytes);
  stdout.writeln('Generated ${output.path}');
}

bool _equal(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
