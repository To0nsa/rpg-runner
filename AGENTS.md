# AGENTS.md

Repo-wide instructions for AI coding agents (Codex, ChatGPT, etc.).

## Project direction (high-level)

This repo is a **Flutter (Dart) + Flame** runner game. v0 is complete; the focus is now on **extending and enhancing the game**, especially building a **scalable architecture for multiple levels** (at least two playable levels, with the ability to add more cleanly).

For detailed architecture rules and conventions when editing gameplay code, follow `lib/AGENTS.md` (it has stricter, layer-specific guidance).

## Consent before changing code

When the user asks a question (e.g. “how do I…?”, “why…?”, “is it possible…?”) or explicitly says “no code / just answer”:

- Do not make code changes. Answer with options/tradeoffs only.
- If implementation would help, ask for confirmation first before editing any files.

Only implement changes when the user clearly requests it (e.g. "please implement", "make the change", "can you do X in the repo?").

## Documentation upkeep

When you implement changes, keep documentation in sync (add new docs when needed, not just code):

- Update architecture/contract docs when boundaries or APIs change: `lib/AGENTS.md`, `docs/building/plan.md`
- Update milestone/checklists and follow-ups when scope shifts: `docs/building/TODO.md`
- Update user-facing usage/entrypoints when behavior changes: `README.md`, public API docs (e.g. `lib/runner.dart`)
