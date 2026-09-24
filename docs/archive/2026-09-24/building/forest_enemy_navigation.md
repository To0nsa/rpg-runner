# Forest enemy navigation repair

Accepted scope: diagnose and repair the failures in the
[forest traversal audit](../audit/forest_enemy_traversal_2026-09-24.md), including
navigation, physical movement capability, or authored terrain where supported
by traces. Preserve the separate Grojib/Hashash contact limits and deterministic
Core authority; do not make impossible transitions pass through collision.

- [x] Regenerate current authored content and trace failed graph transitions.
- [x] Identify reachable routes, execution failures, and capability limits.
- [x] Implement focused fixes and regression coverage for their failure modes.
- [x] Pass the full forest traversal matrix and retain rejection of impossible
  slopes, jumps, and obstructed landings.
- [x] Update TDD/GDD, replay compatibility, and validation evidence.
- [x] Validate Core analysis/tests, Flutter Core tests, and replay worker tests
  and compiled benchmark; archive this plan and resolved audit on completion.

Completed with navigation recovery, facing-correct graph capsules, denser
takeoff sampling, connected-facet footholds and five small chunk adjustments.
Movement capabilities, system ordering and command semantics are unchanged.
All nine Forest cases and three flat controls pass. Gameplay compatibility is
`2026.09.6` across client, Functions and worker. Deployment, pre-live test-state
reset and container throughput verification remain operational release work.
