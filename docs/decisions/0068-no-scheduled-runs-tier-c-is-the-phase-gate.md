# ADR-0068: No scheduled runs; Tier C is the phase gate; the merge queue and fleet reporter are retired

- Status: Accepted (Jon, in chat 2026-10-27)
- Date: 2026-10-27
- Supersedes: [ADR-0021](0021-fast-gate-at-merge-full-gate-nightly.md) on the nightly half (its
  five-minute acceptance budget stands); [ADR-0016](0016-no-forge-local-verification.md) on the
  merge queue (its no-forge decision stands)

## Context

Jon, 2026-10-27, reviewing `tools/`: "I don't really need 'nightly' checks, only tests by phase and
pull request are really needed", and the tiers should be unit, component and integration (A/B/C).

Measured before the change:

- `tests/nightly/checks.txt` held 666 executable lines, 593 of them per-bead re-runs of
  `tools/tier-c.sh`. Its runner, `tools/run-nightly-checks.sh`, was invoked by nothing: the two
  scheduled tasks ran `tools/nightly.sh tier-c` (daily) and `tools/nightly.sh corpus-tier3`
  (weekly), and neither called it. ADR-0021 said it ran every night; it did not.
- Some durable proofs ran nowhere except `checks.txt`, or nowhere at all: the C++ unit suites
  (`check-core-tests.sh`, `check-oofnd.sh`, ...), the deployment flavour (ADR-0066), and the
  guards' own failure proofs (`guardrails-selftest`, `desktop-lock-rogue-proof`, the gui-lock and
  tier-a probes, `check-file-modes.sh`).
- The merge queue (`tools/merge-queue.sh`) was dormant since ADR-0067: work lands as a pull request
  Jon merges.
- `tests/fleet` (the Hermes-era fleet reporter's tests) was red, because the cleanup that deleted
  `docs/fleet/` and `docs/infra/` removed its inputs. That made Tier B red.

## Decision

1. **No scheduled runs.** `tools/nightly.sh`, `tools/run-nightly-checks.sh`,
   `tools/install-scheduled-tasks.ps1` and `tests/nightly/checks.txt` are deleted, and the two
   Windows scheduled tasks are unregistered. The full corpus (`bash tools/corpus.sh tier3`) is run
   by hand when wanted.
2. **The tiers:**
   - **A**: one file, in the edit loop: `tools/tier-a.sh <file>`.
   - **B**: the pull-request gate: `tools/tier-b.sh`.
   - **C**: the phase gate: `tools/tier-c.sh`, run at phase end and before a phase PR. Tier C
     gains three stages that replace `checks.txt`:
     - `unit`: the C++ unit suites Tier B does not run;
     - `deployment`: ADR-0066's flavour checks;
     - `selftests`: the guards' failure proofs, `gen-callobjc-entity-table.py --check` and
       `js-api-contract.sh`.

     Each stage is a fixed list in `tier-c.sh` that runs every command even after a failure.
3. **A slow proof a bead wants kept** goes into one of those lists, not into a bigger acceptance
   budget.
4. **Retired with their subjects:**
   - the merge queue (`merge-queue*`);
   - the fleet reporter (`fleet_reporter.py`, `fleet-report.sh`, `tests/fleet/`, Tier C's
     `fleetdata` stage);
   - the SpiderMonkey/QuickJS differential (`tier-c-diff.sh`, `--backend`);
   - `check-beads-db-merge.sh`.

   Their tests are retired on record in `tools/retire-test-approvals.txt` (ADR-0049).

## Consequences

- Tier B can be green again; the `tests/fleet` floor is gone.
- A proof that used to run every night now runs at phase end. A regression it would have caught
  is found later, but by a run that does happen rather than one that was believed to.
- Phase docs that cite `checks.txt` lines or the merge queue are records of their time and are not
  rewritten.

## History

- 2026-10-27: Accepted (Jon, `tools/` review).
