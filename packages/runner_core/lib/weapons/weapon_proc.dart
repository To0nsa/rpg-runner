import '../combat/status/status.dart';

/// Hook points where weapon procs can trigger.
enum ProcHook { onHit, onBlock, onKill, onCrit }

/// A status proc carried by an ability or item's hit payload.
///
/// When [hook] triggers, [chanceBp] determines whether the selected status
/// profile applies with this source's local [statusTuning].
class WeaponProc {
  const WeaponProc({
    required this.hook,
    required this.statusProfileId,
    this.statusTuning = const StatusProfileTuning(),
    this.chanceBp = 10000,
  }) : assert(
         chanceBp >= 0 && chanceBp <= 10000,
         'chanceBp must be in [0..10000]',
       );

  /// When this proc can trigger.
  final ProcHook hook;

  /// The status effect profile to apply.
  final StatusProfileId statusProfileId;

  /// Local effect values; omitted fields inherit the shared profile defaults.
  final StatusProfileTuning statusTuning;

  /// Probability of triggering in Basis Points (100 = 1%, 10000 = 100%).
  final int chanceBp;
}
