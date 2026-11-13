# Campaign obstacle, jump and resources tutorial

## Scope and acceptance

Reporting for Duty adds one authored three-step sequence at entry to
`mission_chunk_2`: obstacle, Jump, resource bars. All three steps pause simulation;
Next advances the first two, and a fresh Jump gesture dismisses the last step,
resumes through host lifecycle guards and performs the real jump. Stamina remains
Core-owned. Jump and resources are revealed progressively and retained. Existing
lessons, restart, suspension, hidden-HUD keyboard Play and other modes retain their
behavior. The obstacle spotlight uses chunk-local authored bounds and the existing
world/view transform. No geometry, replay encoding or gameplay tuning changes.

The editor edits the three steps as one sequence, including English/French text,
chunk attachment and manually drawn spotlight shapes. Shared HUD/control widgets
provide runtime and authoring targets. Strict source decoding rejects missing or
invalid steps and unknown chunk references. Captured Play and generated product
metadata use the same source. Existing unrelated dirty work is preserved.

## Checklist

- [x] Extend the bounded presentation schema and route-reference validation.
- [x] Implement step progression, fresh Jump admission and lifecycle integration.
- [x] Share Jump/resource targets and project the obstacle spotlight correctly.
- [x] Add editor authoring and Reporting for Duty source; regenerate catalogs.
- [x] Validate decoding, editor round-trip, real spawn-to-chunk traversal, input,
      pause/restart, stamina use and preview geometry in focused checks.
- [x] Review captures and complete Windows editor build; update current docs and
      archive this checklist with exact evidence and limitations.

## Decisions

- The chunk begins at world x=600; its rock is the existing prefab at local
  (140, 186), scale 0.6, with visual bounds approximately (15, 138, 250, 96).
- Informational Next steps do not tick the world. The final fresh Jump is admitted
  by the same host gate used for fresh movement, including keyboard-only preview.
- New scope is a fourth bounded sequence type, not a general scripting engine.

## Review adjustments

- Keep Next outside the text scroller; enlarged French text remains navigable.
- Preserve controller-keyed resource animation reset under the stable spotlight target.
- Reject dangling chunk attachments in decoding and guard route deletion in the editor.
  Synthetic route fixtures explicitly remove production route-bound tutorials.
- Existing authored source was ahead of its generated catalogs at task entry.
  Regeneration retained the existing spawn x=240 and coin x=504 rather than restoring
  stale generated positions; this work edits no authored marker or terrain geometry.
- Resource copy identifies the middle ability bar by position: Willow uses gold
  supplies while Éloïse uses blue mana. The stamina explanation stays shared.

## Outcome

Implemented and verified locally. The final Windows release editor build passed;
current contracts and exact checks/artifact identity are in the
[verification record](../../../verification/campaign-jump-tutorial-2026-11-13.md).
Physical-phone, full-route, web and monitor calibration acceptance were outside
this feature's local validation; no unresolved implementation findings remain.
