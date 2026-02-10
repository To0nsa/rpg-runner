import 'package:flutter/services.dart';

/// Low-level haptics driver abstraction.
///
/// This indirection keeps UI feedback logic testable and centralized.
abstract interface class UiHapticsDriver {
  void selectionClick();
  void lightImpact();
  void mediumImpact();
  void heavyImpact();
}

/// System-backed haptics driver using Flutter's platform channels.
class SystemUiHapticsDriver implements UiHapticsDriver {
  const SystemUiHapticsDriver();

  @override
  void heavyImpact() => HapticFeedback.heavyImpact();

  @override
  void lightImpact() => HapticFeedback.lightImpact();

  @override
  void mediumImpact() => HapticFeedback.mediumImpact();

  @override
  void selectionClick() => HapticFeedback.selectionClick();
}
