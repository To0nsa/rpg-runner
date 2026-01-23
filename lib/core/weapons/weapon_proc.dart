import '../combat/status/status.dart';

/// Hook points where weapon procs can trigger.
enum ProcHook {
  onHit,
  onBlock,
  onKill,
  onCrit,
}

/// A single proc effect that can be attached to a weapon.
///
/// When the specified [hook] triggers, there's a [chance] to apply
/// the status effect defined by [statusProfileId].
class WeaponProc {
  const WeaponProc({
    required this.hook,
    required this.statusProfileId,
    this.chance = 1.0,
  }) : assert(chance >= 0.0 && chance <= 1.0, 'chance must be in [0..1]');

  /// When this proc can trigger.
  final ProcHook hook;

  /// The status effect profile to apply.
  final StatusProfileId statusProfileId;

  /// Probability of triggering (1.0 = 100%, 0.5 = 50%).
  final double chance;
}

/// Bridge helper: Converts legacy statusProfileId to effective procs list.
///
/// Used by future payload builders (Phase 4+). Not consumed in Phase 2.
List<WeaponProc> effectiveWeaponProcs({
  required List<WeaponProc> procs,
  required StatusProfileId legacyStatusProfileId,
}) {
  if (procs.isNotEmpty) return procs;
  if (legacyStatusProfileId == StatusProfileId.none) return const [];
  return [
    WeaponProc(
      hook: ProcHook.onHit,
      statusProfileId: legacyStatusProfileId,
      chance: 1.0,
    ),
  ];
}
