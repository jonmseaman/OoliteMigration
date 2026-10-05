# ADR-0059: The per-module upstream freeze policy

- Status: Accepted (delegated 2026-10-05: Jon delegated the human-assigned beads to the orchestrator's best judgement; ratified as proposed, bead oo-1x6ak; record in [delegated-2026-10-05.md](delegated-2026-10-05.md))
- Date: 2026-09-30
- Beads: oo-kih (this ADR, `docs/UPSTREAM_DELTA.md`, `tools/upstream-delta.sh`, the
  upstream-tracker prompt)

## Context

[Architecture §6.3](../architecture.md) item 5 says: once Phase 3 starts on a module, stop taking
upstream changes to it and port them by hand, tracked in `docs/UPSTREAM_DELTA.md`. It does not say
what a module is, when Phase 3 has "started" on one, how a `git subtree pull --squash` (ADR-0017)
can leave part of the tree alone, or who ports what. The execution model gives the Upstream tracker
the monthly sync and the delta entries, and makes it escalate any conflict inside a frozen module;
no tracker task existed yet. The subtree was added once (2026-09-10, upstream `dc55e3e05`) and has
not been synced since.

## Decision (default in effect)

1. **A module is one directory** under `upstream/oolite/src`, not including its subdirectories.
   Every directory that holds source is listed in `docs/UPSTREAM_DELTA.md` as `frozen` or `open`.
2. **A module is frozen once it holds Phase 3 work**: a `cxx::` class or an `+ObjCBridge` facade.
   `tools/upstream-delta.sh --check` fails while such a module is open, or while a source
   directory is missing from the table, so starting a module cannot skip freezing it. Directories
   the migration created (`oofnd`, `oofnd/objc`, `Core/Scripting/ooscript`) are frozen too.
   Freezing is one-way until Phase 6.
3. **The sync takes ours in frozen modules.** The upstream-tracker task runs
   `git subtree pull --prefix=upstream/oolite upstream master --squash`, then
   `tools/upstream-delta.sh --restore-frozen <pre-pull commit>`, which returns every frozen module
   to its pre-pull state (deleting files upstream added there). A conflict inside a frozen module
   is therefore never resolved in the sync commit; it becomes a port. Open modules and everything
   outside `src/` take the merge, and the tracker resolves their conflicts under the usual gates.
4. **Each upstream commit that touched a frozen module** (`--pending <upstream ref>`, from the
   recorded baseline) becomes one row in the delta table and one `fleet` bead (label
   `upstream-delta`) that ports it into the converted code. Rows are `to-port`, `ported` or
   `not-applicable` (code the migration deleted or replaced, with the reason).
5. The baseline line in `docs/UPSTREAM_DELTA.md` is the last synced upstream commit; the tracker
   moves it in the same commit as the sync.

## Consequences

- No upstream change reaches converted code unreviewed; each one costs a bead. At ~340 upstream
  commits a year, most touching `src/Core`, expect a handful of port beads a month.
- Frozen modules diverge from upstream by design; the fork's `migration` branch (ADR-0017) is the
  only place the two meet.
- Alternative rejected: freezing per file. It matches conversion granularity, but the table would
  track hundreds of rows and a sync would still conflict on headers shared across a directory.
- Alternative rejected: no sync at all until Phase 6. It defers every port into one unbounded
  merge, which §6.3 calls unmergeable.

## History

- 2026-09-30: proposed with recommended default (bead oo-kih).
