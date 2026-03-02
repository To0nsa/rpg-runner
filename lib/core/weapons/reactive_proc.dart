import '../combat/status/status.dart';

/// Hook points where defensive/reactive procs can trigger.
enum ReactiveProcHook {
  /// Triggered when the owner takes non-zero applied damage.
  onDamaged,

  /// Triggered when incoming damage crosses below [lowHealthThresholdBp].
  onLowHealth,
}

/// Runtime target for a reactive proc status application.
enum ReactiveProcTarget {
  /// Apply status to the owner of the proc.
  self,

  /// Apply status to the attacker/source entity that caused the hit.
  attacker,
}

/// A reactive proc attached to gear (typically offhand/shield).
///
/// Unlike [WeaponProc], these hooks are evaluated from post-damage outcomes
/// (reactive flow), not from outgoing hit payloads.
class ReactiveProc {
  const ReactiveProc({
    required this.hook,
    required this.statusProfileId,
    this.target = ReactiveProcTarget.self,
    this.chanceBp = 10000,
    this.lowHealthThresholdBp = 3000,
    this.internalCooldownTicks = 0,
  }) : assert(
         chanceBp >= 0 && chanceBp <= 10000,
         'chanceBp must be in [0..10000]',
       ),
       assert(
         lowHealthThresholdBp >= 0 && lowHealthThresholdBp <= 10000,
         'lowHealthThresholdBp must be in [0..10000]',
       ),
       assert(
         internalCooldownTicks >= 0,
         'internalCooldownTicks cannot be negative',
       );

  /// Trigger hook.
  final ReactiveProcHook hook;

  /// Status profile applied when this proc succeeds.
  final StatusProfileId statusProfileId;

  /// Receiver of the resulting status.
  final ReactiveProcTarget target;

  /// Probability in basis points (`10000 == 100%`).
  final int chanceBp;

  /// HP threshold in basis points for [ReactiveProcHook.onLowHealth].
  /// Ignored for other hooks.
  final int lowHealthThresholdBp;

  /// Per-entity cooldown in ticks for this proc (`0 == no cooldown`).
  final int internalCooldownTicks;
}
