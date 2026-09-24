import 'package:runner_core/traps/trap_placement.dart';

/// Parses HP to hundredths without rounding; invalid precision/range returns null.
int? parseTrapDamage100(String text) {
  final value = _parseScaled(text, 2);
  return value != null && value > 0 && value <= TrapPlacement.maxDamage100
      ? value
      : null;
}

/// Parses seconds to milliseconds; invalid precision/range returns null.
int? parseTrapWindupMs(String text) {
  final value = _parseScaled(text, 3);
  return value != null && value <= TrapPlacement.maxWindupMs ? value : null;
}

String formatTrapDamage100(int value) => _formatScaled(value, 2);
String formatTrapWindupMs(int value) => _formatScaled(value, 3);

int? _parseScaled(String text, int places) {
  final match = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(text.trim());
  if (match == null) return null;
  final whole = match[1]!;
  final fraction = match[2] ?? '';
  if ((whole.isEmpty && fraction.isEmpty) || fraction.length > places) {
    return null;
  }
  return int.tryParse(
    '${whole.isEmpty ? '0' : whole}${fraction.padRight(places, '0')}',
  );
}

String _formatScaled(int value, int places) {
  final digits = value.toString().padLeft(places + 1, '0');
  final whole = digits.substring(0, digits.length - places);
  final fraction = digits
      .substring(digits.length - places)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole : '$whole.$fraction';
}
