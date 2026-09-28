# ADR-0049: Intentional retirement of a unit test when its subject is deleted

- Status: Accepted (Jon, 2026-09-28, in chat; recorded by Claude Code)
- Date: 2026-09-28
- Beads: oo-iobt (blocked), discovered from guardrails vs bead AC

## Context

Bead oo-iobt deletes the transitional `NSUserDefaults+OODefaultsBridge` (and
`NSUserDefaults+Override`) once every caller is on `oo::Defaults`. Its description
also deletes `tests/unit/game/test_defaults_bridge.mm` and the then-empty
`tests/unit/game/` suite (`tools/check-game-unit.sh` and the meson subdir).

`tools/guardrails.sh` rule 2 refuses any deleted path under `tests/` (CLAUDE.md:
never modify or delete a test). The bead's acceptance requires both the deletion
and a green `bash tools/guardrails.sh`. Those two requirements cannot both hold
under today's guard.

The test's subject is gone; keeping it would fail to compile. Rewriting it into a
different suite guts live units and also fails rule 2. Soft-parking forever leaves
`libgnustep-base` removal (oo-qps) blocked on a dead shim.

## Decision (recommended default)

When a bead's description **names** a unit test whose sole subject is a transitional
shim the same bead deletes, deleting that test (and its suite wiring if the suite
becomes empty) is an allowed exception to rule 2.

Implementation, until Jon picks another shape:

1. Add `tools/retire-test-approvals.txt` (same spirit as `tools/rebless-approvals.txt`):
   one path per line, plus a one-line reason; a change may not approve itself.
2. `check_tests` in `tools/guardrails.sh` treats a deleted path listed there as
   `note` (allowed), not `bad`.
3. Bridge-deletion beads that empty `tests/unit/game` also remove
   `tools/check-game-unit.sh` and the tier-b `game-unit` stage, and adjust tier-c's
   stage count — already drafted on `bead/oo-iobt`.

Default until Jon says otherwise: proceed with (1)–(3) on the next oo-iobt attempt
after the approvals file lands in a separate infra bead Jon can rebless by
committing the path lines.

## Consequences

- Rule 2 stays hard for every other test deletion and for gutting.
- Shim-retirement beads stop deadlocking against their own acceptance.
- Jon still controls which paths may retire, via the approvals file (no agent
  self-approval).
