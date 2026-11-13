# Campaign water introduction

Completed November 13, 2026. See [local verification](../../../verification/campaign-water-tutorial-2026-11-13.md).

Implement the accepted water approach card and optional first-swim hint in
Reporting for Duty. Pool geometry and swimming mechanics remain unchanged.
The worktree already contains substantial unrelated and prior tutorial work;
preserve it. Pre-change task files are captured in ignored
`build/water_tutorial_baseline/` for review.

## Acceptance and milestones

- [x] Strict bilingual authored water-region attachment and optional swimming
  lesson; resolve against the captured mission in both Build and Play.
- [x] Pause on approach after the rock, including airborne approaches. Fresh
  movement resumes. On actual first swimming state, fresh Jump resumes and
  performs a real stroke through ordinary input. Optional hints never block
  later mandatory lessons; completed lessons do not repeat on backtracking.
- [x] Reuse world spotlight projection, real Jump target, lifecycle/input gates
  and localized panel editor. Allow region selection, approach distance, text
  and manual spotlight edits through the existing transaction path.
- [x] Author Reporting for Duty, regenerate outputs, test source/runtime/input/
  editor behavior, review the diff, and update implemented contracts.
- [x] Rebuild Windows editor after checks; record local evidence and limitations.

Validation: focused pipeline, tutorial/runtime and editor tests; targeted
analysis, content freshness and localization checks. Use real committed Core
swimming state and continuous mission traversal for the new behavior. No pool
geometry changes, broad enemy traversal suites or cloud deployment are needed.
