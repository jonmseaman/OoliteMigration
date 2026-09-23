# ADR-0047 — The Tier-1 corpus reports a reviewed, byte-pinned content failure as KNOWN

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-1gc.7, 2026-09-23;
ADR-0013, CLAUDE.md rule 10). Made under Jon's 2026-09-23 authorisation to resolve `human` beads
by best judgement. Jon may override.
**Date:** 2026-09-23
**Refines** the Tier-1 corpus verdicts in `tools/oxp_load_check.py` (beads oo-het, oo-kcrw) and
the corpus stages of `tools/tier-b.sh` and `tools/tier-c.sh`.

## Context

`oolite.oxp.Norby.Carriers` has kept the Tier-1 corpus red on both JS engines since oo-1gc.6. It
logs 10 error lines: five `[shipData.load.error] ... the shipdata.plist entry "<x>-carrier" has
unresolved subentit...` and five `[oxp-standards.error]: Bad subentity definition found`.

The diagnosis was made without reading the expansion. The group was run through the corpus runner
with a loose `AddOns/logcontrol.plist` (game configuration) that turns on
`shipData.load.progress` and `effectData.load.progress`. All 10 lines fall between the effect
pass's `Finished resolving like_effects...` and `Finished cleaning up subentities...`. None fall in
the ship pass. `OOShipRegistry -loadShipData` calls `-canonicalizeAndTagSubentities:` once for
shipdata and once for effectdata. Each call resolves subentity keys only in the dictionary it is
given, and both calls use the same message, which says "shipdata.plist". So the `*-carrier`
entries are visual effects whose subentities name ship keys. Every one of those keys exists in core
`shipdata.plist`, but the effect pass cannot resolve a ship key. The pre-migration
`OOShipRegistry.m` has the same two passes and the same message, so 1.93 on SpiderMonkey fails the
same way. That matches the both-engines observation. This is a content defect, and it is not a
migration regression.

The corpus had two outcomes for this group, and both were wrong:

- **ERRORS for ever.** A permanently red tier protects nothing. Every real regression hides
  behind the known red, and the phase gate has to carry the same item forward each time.
- **Change the engine** so that effects resolve ship keys. That changes 1.93 behaviour, which is
  outside the migration's remit.

## Decision

1. **A reviewed list.** `tools/oxp-corpus/known-content-failures.json` lists the Tier-1 groups
   whose errors are diagnosed content defects. Each entry must have:
   - the group name;
   - the sha256 of every staged member's bytes;
   - the bead ids;
   - a diagnosis that was reached without reading expansion content;
   - the exact expected error lines, with timestamps stripped.

   A malformed list is a harness error (rc 2). It never counts as an empty list.
2. **KNOWN.** A listed group reports `KNOWN` only if the member bytes match the pinned hashes and
   the run's error lines equal `expected_errors` exactly, compared as a multiset. `KNOWN` is
   non-fatal, like `PASS`. Its lines are still printed and still recorded in the JSON.
3. **KNOWNCHG turns the tier red.** A listed group reports `KNOWNCHG` in any of these cases:
   - a new error line;
   - a duplicated error line;
   - a changed error line;
   - a missing error line;
   - no errors at all (the loader changed);
   - different member bytes.

   A run that fails before the error scan keeps its own red verdict (NOTLOADED, STARTUP and so
   on). An unlisted group is never relabelled.
4. **The gates count KNOWN as passing.** The corpus stages of `tier-b.sh` and `tier-c.sh` count
   `^(PASS|KNOWN) ` against the checked count. Their floors and their rc checks do not change.
5. **Proof.** Case 6 of `tools/corpus.sh selftest` runs offline in about 2 s. It checks that an
   exact match gives KNOWN, and that each drift listed in item 3 gives KNOWNCHG. It also checks
   that pre-scan failures and unlisted groups are untouched, and that a malformed list is
   rejected. Three mutants each turn the selftest red:
   - a subset match instead of an exact one;
   - the byte pin removed;
   - KNOWNCHG accepted as passing.
6. **Adding an entry changes what a test accepts** (rules 2 and 7). Each entry needs its own bead
   and a diagnosis from engine source and logs only. Rule 6 still applies: never read the
   expansion.

## Consequences

- Norby.Carriers reports KNOWN on the current build, and the Tier-1 corpus can go green again.
  Tier-1 now tracks regressions, not one standing defect.
- If a future engine change makes effects resolve ship keys, or changes this message, the group
  goes red (KNOWNCHG). Someone then has to decide on purpose. The change cannot slip through.
- NOMANIF is unchanged. It is still counted as not-PASS by `tier-c.sh`'s pass==checked check,
  which leaves the full tier red on the five legacy test-oxps. That inconsistency predates this
  ADR and is left for its own bead.
- The author fix is recorded in `docs/EXPANSION_MIGRATION.md` (row E11).
