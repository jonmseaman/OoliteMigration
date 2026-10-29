# Pitfalls

Things that cost a previous run real time. Read the one that matches what you are about to do.

## Environment

- **The UCRT64 `jq` writes CRLF, and a bead id with a trailing `\r` fails silently.** Every value
  that leaves `jq` and becomes a shell variable must go through `tr -d '\r'` (`nocr` in
  `_lib.sh`). The symptom is a script that loops over `jq` output, does nothing and exits nonzero
  with no message: it looks like "nothing to land". Run it under `bash -x` and look for `$'…\r'`.
- **Put `/ucrt64/bin` on PATH for every shell call that runs an acceptance block.** `accept.sh`
  inherits the calling shell; a desktop-launched terminal has no MSYS2 prefix, so lines calling
  `python3` die with `[exit 127]` on correct work. An exit 127 is an environment defect, not a
  verdict: fix PATH and re-run before it is written into the notes or counted as stale.
- **Orphaned `oolite.exe` poisons game-launching lines.** A game started through a test subprocess
  is not always killed when its parent ends; it keeps the console port and handles on the app dir.
  Symptoms: `TimeoutExpired`, `ConsoleError: no answer`, `Device or resource busy`, with a long
  wall time. Before a launching line, `ps -W | grep -ci oolite` should be 0. Kill with
  `ps -W | grep -i oolite | awk '{print $4}' | while read p; do /c/Windows/System32/taskkill.exe /PID $p /F; done`
  (MSYS mangles `taskkill //PID`). Log the process count next to a failure so it diagnoses itself.
- **Launching beads contend with each other** for CPU, the console port and the app dir. Run at
  most one or two at a time; offline beads parallelise freely. When a launching line fails, check
  sibling load before believing it. A GUI line (`tests/gui`) that fails under load should be re-run
  alone before it is recorded as a failure.

## Beads

- **`bd unclaim` and `bd update --claim` must use the same actor.** The worker claims as
  `worker_actor`; `bd`'s default is `git user.name`, so a bare `bd unclaim` is refused. Pass
  `--actor "$(worker_actor)"`.
- **`bd close` is refused, for you too.** A bead closes only when `land.sh` sees its epic's branch
  merged into `develop`. `bd update --status closed` is the same act: never do that for any reason.
  A duplicate gets a note pointing at the real bead and stays open.
- **Every bead needs a parent epic.** `branch.sh` and `accept.sh` stop with "has no parent epic"
  otherwise. Attach it with `bd update <id> --parent <epic>`.
- **One commit per bead is made by `accept.sh`, not by you.** Commit as often as you like during the
  tick; after the gate passes the script squashes everything since `base_commit` into
  `<id>: <title>`. Do not rebase, amend or reset yourself.
- **A parked bead's commits are reverted, not dropped.** `park.sh` adds revert commits on the epic
  branch so later beads still build; history is never rewritten.
- **`bd update --acceptance` / `--append-notes` change bead data, not the git tree.** They need no
  commit, and fixing a bead's gate is not the same act as editing the tree it judges.
- **Check for an existing bead before filing one** (`bd list --json`, grep the symptom). Concurrent
  sessions file the same bug twice; work the real one and leave your duplicate open with a note.
- **`human` is not a terminal state.** After a root-cause fix lands, `bd list --label human` for
  beads parked on that signature and reclaim them; they already carry their retry history.

## Writing acceptance lines

- **Each line runs in its own `bash -o pipefail -c`; shell state does not cross lines.** A variable
  set on one line expands empty on the next (`mkdir: cannot create directory ''`). Anything that
  shares state is one logical line, joined with `&&` or `;`. Test the joined line under
  `bash -o pipefail -c "$CMD"` exactly as `accept.sh` will.
- **Prove the line fails on unfixed code, not only that it passes on fixed code.** A backslash
  doubled by the round trip through `bd`/JSON (`foo\.bar` → `foo\\.bar`) made a `git grep` match
  nothing on any tree, so it was green forever. After storing, read it back with `bd show --json`
  and run it on a tree where the defect is known to be present. In a Python heredoc use a raw
  string, or `\b` becomes a backspace byte; assert `chr(8) not in acc` on the read-back.
- **Replay a stored block the way `accept.sh` does.** `while read` over a file with no trailing
  newline drops the last line; `accept.sh` uses a here-string and does not. Assert lines-run equals
  lines-stored, taking the stored count from `bd show --json`.
- **`grep -q` on the read side of a pipe fails under `pipefail` with `[exit 141]`** (SIGPIPE) on a
  correct match. Use `grep pattern >/dev/null` instead.
- **A line-number exemption goes stale when the file is edited.** Re-derive it from the current
  file, and prefer matching symbol names. An exclusion regex without a leading `^` can match
  nowhere in `grep -n` output and make the whole line fail; run it before storing.
- **A bead that renames a file makes its own stored acceptance stale.** `No such file or
  directory` on the old name is a bead-data fix (`bd update <id> --acceptance`), not a code defect.
- **A build is part of the proof for a source change.** Acceptance that only reruns an already
  built binary can pass or fail on a stale build. Build once (`cd oolite-dev && ./mk.sh build test`)
  and then run the tests.

## Judging a failure

- **Reproduce a failure directly before blaming the bead.** Run the failing test on its own
  (`cd oolite-dev && tests/run.sh component -k <name>`, or `meson test`) on the base branch and on
  yours. Same failure on the base branch is a pre-existing defect: log it, do not count it against
  the bead.
- **A worker's fix to the one named failing test can break siblings** that share a constant or
  fixture. Re-run the whole test file, not the `-k` node, before trusting it.
- **Verify a pre-existing-failure claim in a disposable checkout** (`git worktree add --detach
  <path> develop`), never by checking out files inside a branch you do not own.
- **Verify any ADR or decision doc a worker cites.** There is no ADR folder; old ADRs are under the
  git tag `archive/phase-0-4-docs` and bind nothing. A citation never justifies a weaker gate.
- **Codemods must be string/comment-aware and tried on every real call-site shape.** Fixtures
  written by the author of the regex only exercise the shape the regex was written for. Grep the
  real tree for the target token, group hits by shape, and run the script on one real file per
  shape.
