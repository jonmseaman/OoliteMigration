# Story: <id> — <two-to-three-sentence title>

Bead `<id>` · Phase N · Priority P · Exemplar `<path>`

## Task

Two or three sentences. Absolute paths. Every type and signature used either already compiles in
the tree or is quoted verbatim below.

**Do it the way `<exemplar absolute path>` does it.**

## Files

The files or area this unit touches, or the pattern and the tool for a tree-wide sweep:

- `/abs/path/one`
- `/abs/path/two`

## Acceptance (run by the wrapper, never by the agent)

Each must exit nonzero before the change and zero after:

```bash
cd oolite-dev && ./mk.sh build test
cd oolite-dev && tests/run.sh unit
```

Add `tests/run.sh component -k <scenario>` when the unit changes observable behaviour.

## Prohibitions (verbatim in every story)

- Do not modify or delete tests. If the test is wrong, stop and report. **Adding** a test is not
  prohibited and is expected where this unit changes observable behaviour: add a scenario to
  `tests/component/features/` using steps that already exist. Needing a *new step* fails readiness
  check 3 — stop and file a bead.
- Do not add `-Wno-*`, `#pragma` diagnostic suppressions, or `[[maybe_unused]]` to silence a warning.
- Do not mark this unit done. The wrapper does that after running the acceptance commands.
- Do not read expansion (OXP/OXZ) content. If the task appears to need it, stop and report.
- Commit only to the branch you were given. Never push to `develop`, `master` or `main`.

## Carry-over

The one channel that survives between iterations (the bead's notes, `bd update <id> --notes`). Write here what the next
iteration must know: what was tried, what failed, what is half-done.

## Readiness check

| # | Check | ✓ |
|---:|---|---|
| 1 | One tick's work (no line or file cap; sized by pattern or area) | |
| 2 | ≥ 1 command-shaped acceptance criterion | |
| 3 | Zero new interfaces, or each quoted verbatim | |
| 4 | Describable in 2–3 sentences | |
| 5 | Names a worked exemplar | |

Acceptance budget: 300 s by default; set `accept_budget` in the bead's metadata (up to 1,800 s)
when the proof is a full build and test run.
