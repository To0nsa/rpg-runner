# Willow Blink Dash and Lunge Slash art

Requested November 8, 2026. Starting worktree is clean except unrelated
`.flutter_tool_state`; preserve that file. No deployment is authorized.

## Accepted behavior

- Lunge Slash uses the final five-frame strip in each weapon spritesheet.
- Add a separate Blink Dash mobility choice using the teleport strip, including
  its intentionally transparent middle frame.
- Prefer a clear destination just beyond the first nearby obstacle in front.
  Maximum obstacle width matches the widest placed woodcamp tent: its 92-unit
  collision shape scaled by 1.5 in the chunks, or 138 world units before
  Willow's body clearance. Use a bounded approach distance and safe full-capsule
  placement; reject an unreachable exit before charging resources/cooldown.
- Preserve ground/air use, horizontal height, normal Dash, and existing input
  encoding. Start with 4 stamina and a 3-second cooldown. No melee damage.
- Fixed-tick execution, interruptions and replay results must agree. Update
  ownership/catalog/presentation consumers and document the compatibility change.

## Checklist

- [x] Core destination selection, committed execution, animation and Lunge art.
- [x] Shared labels/icons, UI text, backend catalog and replay compatibility.
- [x] Obstacle/clear/blocked/range controls, interruptions, tick rates, replay
  parity and rendered animation verification.
- [x] Review complete diff, record evidence and archive this checklist.

## Validation

Completed locally. See [verification and remaining release boundaries](../../../verification/willow-blink-dash-2026-11-08.md).
Terrain source and navigation fingerprint remain unchanged. No deployment or
phone playtest is claimed.
