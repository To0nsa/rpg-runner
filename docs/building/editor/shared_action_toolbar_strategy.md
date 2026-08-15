# Shared Editor Action Toolbar Strategy

## Status

Implementation complete. Focused test migration and validation are deferred at
the user's request; see the checklist.

## Goal

Every top-level editor route presents one consistent action toolbar, in this
order:

1. Page selector
2. Reload
3. Apply To Files
4. Undo
5. Redo

A right-aligned status area reports Reload/Apply progress, persisted versus
pending state, affected item/file counts, and validation error/warning counts.
Pending-summary failures remain visible through a compact error status with the
full detail in its tooltip.

The toolbar belongs to the home shell. It is the only place that renders those
common actions; a route must not render a second copy inside its workspace.

## Ownership

`EditorHomePage` continues to own route selection, discard confirmation for
reload/route transitions, and keyboard shortcuts. It will also render the
shared action toolbar.

The existing `EditorPageReloadHandler` and
`EditorPageSessionShortcutHandler` contracts preserve page-specific reload and
history behavior. A narrow `EditorPageApplyHandler` contract lets a page state
report whether apply is currently safe and perform its domain-specific apply
flow.

The apply contract intentionally delegates the action back to the page instead
of making the home shell switch on route identifiers. Some pages need behavior
that cannot be flattened safely:

- Level Creator resolves a post-apply Level/theme handoff target.
- Prefab and Chunk block writes while polygon or form operations are active.
- Entities reports source backup artifacts after export.

All repository writes remain in each plugin and `EditorSessionController`; the
toolbar does not write sources directly.

## Route treatment

Entities, Parallax, Level Creator, and Terrain Materials implement the apply
contract directly. Prefab Creator and Chunk Creator delegate it to their
current-schema workspace state, keeping migration-required routes visible but
non-applicable.

Route-specific controls such as active-level selectors, layer/owner selectors,
and diagnostics remain inside their routes. Only the five common controls move
to the shell. The trailing status uses only session-wide state, so it does not
change meaning between routes.

## Validation

Focused widget tests must prove that the shell renders the ordered controls,
that disabled states are respected, that Prefab/Chunk delegate history and
apply behavior, and that page-local duplicate toolbar buttons are absent.
The full editor analyzer and test suite run after the implementation is
complete.
