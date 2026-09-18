# Fleet reporter (bead oo-l7r0)

A **read-only** scheduled job that reads `bd`, the tier logs, `git` and the goldens and writes
exactly one file, `docs/fleet/REPORT-<date>.md`, containing every daily metric defined in
[`docs/infra/4-metrics.md`](../infra/4-metrics.md) plus `days_since_origin_main`,
`days_since_fork_migration` and `fork_migration_matched`.

    tools/fleet-report.sh                                  # generate today's report
    tools/fleet-report.sh --check-only docs/fleet/REPORT-2026-09-18.md
    MODE=claude tools/fleet-report.sh                       # the scheduled claude -p leg

## The two problems this design exists to solve

**"Every metric is present" is trivially satisfiable.** A template of headings, or a wall of
zeros, meets the letter of the definition of done and is worthless. Three things stop that:

1. *The metric list is parsed from the doc, not copied.* `daily_metrics_from_doc()` reads the
   `## Daily` table and slugifies column one; the collector registry is keyed by those slugs. Add
   a row to `4-metrics.md` and the checker goes red naming the new metric. There is no second
   copy of the list to drift out of date.
2. *A measured zero and an unmeasurable metric are different values.* Every figure is either
   `{"value": x}` — where `0` means measured zero — or `{"not_computed": "<reason>"}`. The
   checker rejects a value that is both, neither, has an empty reason, or is `NOT COMPUTED` in
   the payload while the prose prints it as `0`.
3. *Numbers are cross-checked against an independent path.* The proposed-ADR count is recounted
   from `docs/decisions/`, `days_since_origin_main` against `git log origin/main`, and
   `beads.ready` against a second `bd list --json`. Additionally a metric may not claim a value
   when its source file does not exist — that catches the subtlest cheat, a fabricated number
   with a status field repaired to match.

**Read-only is safety-critical on a live fleet.** Sibling workers hold worktrees and
`.beads/issues.jsonl` is append-only shared state. Enforcement, not intention:

- `ReadOnlyGuard.write_text` refuses any path but the single report file the run was told to
  produce;
- `ReadOnlyGuard.run` classifies argv **before** exec and refuses `bd close`, `bd update`,
  `git commit`, `git push`, `git add`, `rm`, and friends — including `git -C <path> commit`,
  which needs the flag-value table in `classify_argv` to catch. The refusal precedes any
  process start, so the exec trace stays empty.

Both are proved to block by `tests/fleet/test_fleet_reporter.py` and
`tests/fleet/gate_mutants.py --guards`, each of which has a **red twin** that reloads the module
with the marked enforcement region stripped and asserts the same action then succeeds. An
enforcement nobody has watched block something is decoration.

## The `claude -p` seam

`tools/fleet-report.sh` has two modes. `MODE=direct` (default) runs `tools/fleet_reporter.py`
in-process; that is what every test and every acceptance line runs. `MODE=claude` invokes
`claude -p --model claude-opus-5` with a read-only `--allowedTools` allowlist and the prompt in
`reporter-prompt.md`, asking it to run the same script and summarise the result.

**MODE=claude has not been executed in this repository.** A delegated worker cannot honestly
exercise it (the CLI may be absent, unauthenticated, or slower than an acceptance budget), so
report generation was deliberately made independent of it: the model leg only narrates a report
the script already produced. No claim here rests on an end-to-end model run.

## Scheduling

Any scheduler that can run one command daily:

    schtasks /create /tn "oolite-fleet-report" /sc daily /st 06:00 ^
      /tr "C:\msys64\usr\bin\bash.exe -lc 'cd /c/Users/jon/OoliteMigration && MODE=claude tools/fleet-report.sh'"

A failed run leaves no partial state: the report is written once, at the end, through the guard.
