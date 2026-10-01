# ADR-0052: A bridged function a unit test calls outlives its bridge

- Status: Accepted (Jon, 2026-09-30, in chat). Recorded from the in-effect default (CLAUDE.md rule 10).
- Date: 2026-09-28
- Beads: oo-m2nh (delete OOStringExpander+FoundationBridge), seam oo-3rb.294, chunks oo-3rb.295..298

## Context

`OOStringExpander+FoundationBridge.h/.mm` (made by oo-3rb.145, ADR-0043 "Transitional
bridges") held the Foundation-typed `OOExpandDescriptionString`, `OOGenerateSystemDescription`
and the `OOExpand*` macros. Its deletion bead requires that nothing outside the bridge use them.
The game callers moved to the `cxx_` forms (the `cxx_OOExpand*` macros from seam oo-3rb.294,
chunks oo-3rb.295..298). Two callers remain that are not game code:

- `tests/unit/expander/test_string_expander.mm` calls `OOExpandDescriptionString` and
  `OOGenerateSystemDescription` with `NSString`/`NSDictionary` arguments; its digests were taken
  through that surface.
- `tools/check-string-expander.sh` compiles the test (and, until now, the bridge `.mm`).

Rewriting the test onto the `cxx_` API is a test modification (rule 2). ADR-0049's retirement
exception does not apply: the test's subject is the expander engine, which stays.

## Decision (recommended default)

A function a unit test calls by name is a tested surface, not transitional bridge API, as the
"called by name" selectors are (ADR-0043 item 21; precedent oo-tj5w, which moved four such
selectors out of a bridge into `PlayerEntityScriptMethods`). So:

1. The two Foundation-typed functions move, unchanged in behaviour, from the bridge into
   `OOStringExpander.h/.mm`, commented as the expander test's surface. Game code does not call
   them.
2. The bridge (the `OOExpand*` macros and their boxing machinery) is deleted as planned.
3. The functions go when the test's Foundation adapter does (with oo-qps), in whichever bead
   moves that test off Foundation.

## Consequences

- The test and its digests are untouched; the bridge deletion does not wait on Jon.
- `OOStringExpander.mm` keeps two `NSString` entry points until oo-qps, which already has to
  move the test.
- `tools/check-string-expander.sh` still names the deleted bridge `.mm` (lines 64-70). It already
  fails earlier on phase-2 (stale stubs, oo-qqz6), so the stale lines are recorded there rather
  than edited here.

## History

- 2026-09-28: proposed by the oo-m2nh worker; default in effect.
