# Pitfalls

Things that cost a previous run real time. They are about **the game and its gates** — the
Hermes-era lessons about worktrees, harvesting and delegation were dropped when the worker became
a Claude Code skill. Read the section that matches what you are about to do; you do not need the
whole file.

A few mention `worktree` or `the orchestrator`: that was the old shape of the loop. The lesson
still holds, read "worktree" as "oolite-dev checkout" and "orchestrator" as "you, the loop".

- **The UCRT64 `jq` writes CRLF, and a bead id with a trailing `\r` fails silently.** Every value
  that leaves `jq` and becomes a shell variable must go through `tr -d '\r'` (`nocr` in `_lib.sh`).
  Measured 2026-10-27: `land.sh` read ids as `oo-1db.6\r`, handed that to `bd show`, got nothing,
  and `set -e` killed the script **with no output whatsoever** — it looked exactly like "there is
  nothing to land" rather than like a failure. The same trap is called out in
  `tools/check-beads-db-merge.sh`. Suspect it whenever a script that loops over `jq` output does
  nothing at all and exits nonzero: run it under `bash -x` and look for `$'…\r'` in the trace.
- **`bd unclaim` and `bd update --claim` must agree about the actor.** The worker claims as
  `worker_actor` (the outer worktree's directory name), but `bd`'s default actor is
  `git user.name`, so a bare `bd unclaim` is refused with "issue claimed by a different actor".
  Pass `--actor "$(worker_actor)"`.
- **Raw `bd close` is refused, for you too.** That is the guard shim doing its job. A bead closes
  in exactly one way: you merge its pull request on GitHub and `scripts/land.sh` sees the merge.
  Nothing you can type closes a bead. If `preflight.sh` says the shim is not on PATH, stop and tell
  the user; do not proceed without it.
- **Export `PATH="/ucrt64/bin:$PATH"` in every shell call that runs an acceptance block.** `accept.sh`
  inherits the calling shell, and a desktop-launched terminal's PATH has no MSYS2 UCRT64
  prefix, so acceptance lines calling `python3` die with `command not found` `[exit 127]` on
  perfectly correct work (observed on oo-5ggu: attempt 1 rejected at line 1; the identical command
  re-run with `/ucrt64/bin` on PATH closed the bead). An `[exit 127]` is an environment defect, not
  a verdict: fix the environment and re-run **before** writing `accept attempt N failed` into the
  notes or counting it toward `BEADS_WORKER_STALE_REPEATS`. Same class as the oo-gla learning, one
  level up — there a bad PATH killed a game launch inside a worker, here it killed the accepter.
- **Do not fill the batch with game-LAUNCHING beads: they starve each other and fail healthy work.**
  Four scenario beads running 10-run stability sweeps at once made oo-rkm's live acceptance line
  fail **six consecutive times**, every failure an instrument signature (`TimeoutExpired ... after
  10 seconds`, `ConsoleError: no answer to 'system.name' within 15s`, `rm: ... Device or resource
  busy`, each logged at `procs=5`/`procs=6`) — while the same line on the same tree measured green
  3/3 an hour earlier. Six identical failures is normally the signature of a broken gate
  (`BEADS_WORKER_STALE_REPEATS` is 5), so this is exactly where an orchestrator wrongly escalates
  healthy work. Launching beads contend for CPU, for the shared console port 8563 and for the
  shared app dir; offline beads (checkers, gates, mutation suites over stored artifacts)
  parallelise freely. **Mix the batch: at most one or two launching beads at a time**, and when a
  launching line fails, check the sibling load before believing it.
- **Before any game-launching line, require `ps -W | grep -ci oolite` to be 0 — orphans poison it.**
  A game a worker launched through a harness subprocess is **not** killed when that worker ends: it
  keeps console port 8563 bound and keeps handles on its staged app copy. oo-rkm's live line failed
  seven times across two sessions (`TimeoutExpired ... after 10 seconds`, `ConsoleError: no answer
  to 'system.name' within 15s`, `rm: ... Device or resource busy`) with **no children running** —
  three orphaned `oolite.exe` were still alive, two of them hours old. After killing them the
  identical line on the identical tree returned **rc=0 in 16s**, against rc=1 after 117s moments
  earlier. MSYS `ps` puts the *Windows* pid in field 4, and `taskkill //PID` is mangled by MSYS
  argument conversion, so kill with:
  `ps -W | grep -i oolite | awk '{print $4}' | while read p; do /c/Windows/System32/taskkill.exe /PID $p /F; done`
  Log the count beside every result: `rc=1 wall=117s oolite_procs=4` diagnoses itself; a bare rc=1
  gets mistaken for a broken gate and, at five repeats, escalates healthy work. A long wall time is
  the tell — the harness is burning its retry budget against a port that will never answer.
- **A component-stage timeout (`[exit 124]`) after several concurrent worker/accept rounds is
  usually orphan-process buildup across ALL of them, not just `oolite.exe` — sweep every process
  tree, not just the game binary.** Multiple workers each running their own `tier-b.sh --fast` in
  parallel leave behind not only orphaned `oolite.exe` (see above) but orphaned `tools/gui-lock`,
  `tools/tier-b.sh`, and `tools/gui-acceptance-recheck` shell trees with PPID 1 (reparented after
  their owning subagent already exited) that keep holding or re-queuing for the desktop lock.
  `ps -W -f | grep -iE "gui-lock|tier-b|oolite"` after a batch of several workers/accepts is
  routine, not exceptional; kill every orphaned line (`kill -9 <pid>` for bash trees, the
  `taskkill.exe` loop above for `oolite.exe`), not just the game processes, before retrying an
  accept that hit a timeout. A single sweep can take two or three rounds — new orphans surface as
  a killed tree's children get reparented — so re-check `ps` after killing, not just once.
- **Replay a stored acceptance block the way `accept.sh` does, or you will silently skip a line.**
  `while IFS= read -r l; ...; done < file` DROPS the final line when the file has no trailing
  newline (measured: `printf 'a\nb\nc' > f` reads **2 of 3**). `accept.sh` is immune because it uses
  a here-string — `done <<<"$acceptance"` — and bash always terminates a here-string (3 of 3). A
  reviewer hit this on oo-zyj1, reported `RAN=6` against 7 stored lines, and nearly filed it as a
  bead defect; the dropped line was the LIVE RED PROOF, the one whose absence most weakens a
  review. Always assert lines-run == lines-stored taken from `bd show --json`, never from your own
  temp file — a count from the file that lost the line cannot detect the loss. A worker that
  validated its own acceptance this way may have left its last line untested while honestly
  reporting success.
- **A stored acceptance line must be proven to FAIL, not just to pass.** A worker built a regex
  acceptance line in python3 (`frame_hash\.GRID_SIZE`) and stored it via `bd update --acceptance`;
  the round trip through bd/JSON doubled the backslash to `frame_hash\\.GRID_SIZE`, which `git grep`
  reads as literal-backslash-then-any-char and matches nothing — on ANY tree, fixed or not. Every
  replay on the fixed tree looked green. Only a reviewer running the stored line verbatim on the
  UNFIXED tree caught it: rc=0, "PASS: no reference remains," while the bug was still there. Rule:
  whenever a stored line embeds a backslash, after reading it back with `bd show --json`, run it on
  a tree where the defect is KNOWN to still be present (pre-fix main, or a throwaway copy with the
  bug reintroduced) and confirm it fails there. Green-only replay cannot detect a gate that can
  never turn red.
- **A regex/text-scan codemod script that rewrites JS_* (or any) tokens must be string/comment-aware, or it corrupts source it should leave alone.** A reviewer caught bead oo-oio's `tools/refactor/js_stubs.py` rewriting matched tokens found INSIDE string literals (e.g. a log message quoting `"JS_PropertyStub"`) and inside comments with call-shaped text (e.g. `// JS_ValueToNumber(context, val, &x)`), because it scanned raw file text with a bare regex/`.find()` and had no notion of what a string or comment span is. A single test fixture had passed only by luck (its one comment mention had no real parens to rewrite). Any codemod/refactor-script bead — and there will be many more of these in a retarget-pattern-across-N-files sweep — must be reviewed by constructing TWO adversarial fixtures beyond the happy-path exemplar: one with the target token inside a string literal, one with a call-shaped mention inside a comment with real arguments, and asserting both are byte-for-byte unchanged after the rewrite. Do not accept a codemod script whose selftest only proves the exemplar file round-trips correctly.
 The same class of bug recurs one level up: a token-shape codemod tuned against a single exemplar
 call site can still corrupt other real call sites that have a different STRUCTURAL shape around
 the same token. Bead oo-oio's `JS_InitClass` rewrite worked on the exemplar's bare
 `sVectorPrototype = JS_InitClass(...)` but stranded the leading type in front of the rewrite for
 the equally-common `JSObject *clockPrototype = JS_InitClass(...)` inline-declaration form — found
 in 3 of 27 real call sites in the tree, none of which the exemplar or fixtures happened to cover.
 Before approving a codemod, `grep -n <target-token>` across the real source tree the script will
 actually run against, group the hits by surrounding shape (leading type declaration, expression
 context, multiple statements per line, etc.), and require the worker to run the script (`--stdout`
 or equivalent dry-run) against at least one REAL file for each distinct shape found, not just the
 synthetic fixtures the worker built — a fixture built by the same author who wrote the regex tends
 to only exercise the shape the regex was written for.
- **A Python heredoc storing acceptance via `bd update <id> --acceptance` MUST use a raw string, or `\b` becomes a literal backspace byte that silently corrupts the regex.** A non-raw `"...\\bJS_...\"` collapses `\b` to `\x08` before it reaches bd; `bd show --json` round-trips that same corrupted byte, so a visual read-back looks fine while accept.sh's shell parse breaks or the regex matches nothing/everything. Always build the string with `r"""..."""`, and after storing, explicitly assert `chr(8) not in acc` in the read-back check.
- **A bead's own approved rename (e.g. `.m`->`.mm`) can leave the stored `tools/tier-b.sh --fast` line missing `OO_APP_DIR` AND pointing at the pre-rename filename — check both.** `tools/tier-b.sh --fast` needs `OO_APP_DIR` pointed at the shared local build or a fresh `accept.sh` checkout fails at `[build]` with "no oolite.exe ... point OO_APP_DIR"; separately, if you patch an existing acceptance string yourself after a worker renamed the file, respell the grep/tier-a targets to the new name too, or tier-a silently PASSes on a file that no longer exists. Fix both together, verified with `ls` in the worktree before storing: `OO_APP_DIR="${OO_APP_DIR:-<repo>/oolite-dev/build/meson_test/oolite.app}" tools/tier-b.sh --fast`.
- **Component-scenario nondeterminism is not confined to whichever 3 scenarios a flake bead names — treat a new scenario's failure as the same class, not a new bug.** oo-sjvz was scoped to s1/s5/s6, but s2 (trader-survival) also flaked on a later, unrelated bead's accept — same role-based-spawn nondeterminism, different scenario. Don't file a new investigation bead per newly-observed flaky scenario; log it as a widening-scope note on the existing escalated flake bead and keep retrying the blocked accept, since the fix (when it lands) will likely cover all of them.
- **Fixing scenario nondeterminism must pin it INSIDE the existing step's Python implementation, never by editing or adding Gherkin step text.** `guardrails.sh`'s test-immutability classifier flags ANY change to a `.feature` step-text signature as "emptying" a live test unit, even a precision-adding rewrite — and adding brand-new step definitions alongside the old ones has the same problem once the `.feature` file is edited to call them. The approach that actually lands: keep every step's wording byte-for-byte identical to what already ran, and move the fix into the step's underlying Python (`world_steps.py`) — e.g. a `role -> pinned ship key` / `role -> pinned bounty` lookup dict inside `_spawn`, so a role-spawned step becomes deterministic without the `.feature` file ever mentioning a ship key. A worker fixing this class of bug should end with a `.feature` diff of **zero** and all determinism logic living in the step implementation only; if the `.feature` diff is non-empty, the fix is in the wrong layer and guardrails will likely reject it.
- **A stored acceptance block runs one line at a time, each in its OWN `bash -o pipefail -c`; shell state does not cross lines.** `accept.sh` reads the stored acceptance with `while IFS= read -r cmd; do ... bash -o pipefail -c "$cmd" ...; done`, so a variable set on one line (`B="$TMPDIR/x"`) is gone by the next line that reads `"$B"` — it silently expands empty and the command fails with a confusing message (`mkdir: cannot create directory '': No such file or directory`), not an obvious "undefined variable" error. This burned two stale-identical rejections on bead oo-kte before the cause was found. FIX: any acceptance script with shared state across statements must be stored as ONE LOGICAL LINE (`;` or `&&`-joined, not real newlines). Before storing with `bd update <id> --acceptance`, test the fully-joined line under `bash -o pipefail -c "$CMD"` exactly as accept.sh will invoke it — a multi-line version that "looks right" and even runs fine interactively (where the whole block executes in one live shell) is not proof, because interactively you never split it into independent subshells the way accept.sh does. This is the worker-prompt.md rule now too, but the orchestrator must also catch it: a `mkdir`/`cd`/file-path failure with an EMPTY path in an accept.sh rejection is this bug, not a real defect — read the notes for a vanished variable before bumping stale_count.
- **A bead's own approved rename (e.g. `.m` -> `.mm`) makes its OWN stored acceptance stale — fix
  the path, don't retry blind.** `accept.sh` rejects with "No such file or directory" on the
  `grep`/`tier-a.sh` line because the acceptance was generated (or written attempt 1) against the
  pre-rename filename, and the worker's approved diff legitimately renamed the file as part of the
  retarget. This is not a code defect: `bd show <id> --json` the `acceptance_criteria`, confirm the
  file at the new name (`ls upstream/.../Foo.mm`), and `bd update <id> --acceptance "<same lines,
  new path>"` (single logical line if it was one before — see the accept.sh-per-line pitfall) before
  re-running `accept.sh`. Do not bump `stale_count`/retry the worker for this; the fix is bd-data
  only and does not need a worker round-trip (see below).
  **`acceptance_criteria: None` (falling back to the bead body's pre-generation filename) is the
  DEFAULT state for a freshly generated js-retarget bead, not an occasional miss** — every instance
  checked (oo-9yr, oo-aa0, oo-af1, oo-c4q, oo-dhx, oo-b8w, oo-bgt, oo-bnq) needed this fix. When a
  `next-bead.sh` batch claims several js-retarget beads at once, check and fix all of them in one
  pass right after `worktree.sh` — `bd show <id> --json` for `acceptance_criteria`, `ls` the
  worktree's directory for the real `.mm` name, store the corrected 3-line block (grep, tier-a,
  `OO_APP_DIR=... tools/tier-b.sh --fast`) — instead of discovering it one accept-rejection at a
  time; the fix is identical across every bead in the sweep and costs nothing to do proactively.
- **`bd update <id> --acceptance/--append-notes` is bd-data, not a git-tracked file.** bd's store
  is dolt-backed and gitignored, so correcting a stale acceptance path or appending a note changes
  nothing `git status` would show and needs no commit. Fixing a bead's own gate is not the same
  kind of act as editing the tree it judges.
- **`tools/tier-b.sh --fast` needs `OO_APP_DIR` pointed at a real build, or every bead's stored
  acceptance breaks in a fresh `accept.sh` checkout.** `--fast` skips the `[build]` stage and reuses
  whatever `OO_APP_DIR` already points at; a bead's stored acceptance line that just says
  `tools/tier-b.sh --fast` works in the worker's own worktree (which has a build) but fails with
  "no oolite.exe at .../oolite.app; point OO_APP_DIR" the moment `accept.sh` replays it in a fresh
  scratch checkout with no build of its own. Fix once per bead: `bd update <id> --acceptance` with
  `OO_APP_DIR="${OO_APP_DIR:-<repo>/oolite-dev/build/meson_test/oolite.app}" tools/tier-b.sh
  --fast` in place of the bare call — this defaults to the repo's one shared local build without
  breaking a caller that already sets `OO_APP_DIR` explicitly.
  **`--fast` NEVER rebuilds, so for a bead whose actual fix is a source/binary change (not a
  test/harness-only change), an all-`--fast` acceptance can pass or fail based on a STALE shared
  binary that predates the fix entirely — it is testing whether the fix compiled, not the fix
  itself.** If the shared binary at `OO_APP_DIR` was built before the bead's commit landed, every
  `--fast` run replays the SAME pre-fix behavior regardless of how correct the diff is; a
  "5 consecutive passes" acceptance can genuinely need those 5 runs to see the fix and still fail
  every time because none of them ever compiled it in. For any bead whose diff touches source (not
  purely tests/harness), store acceptance as ONE real build followed by `--fast` reruns, not all
  `--fast`: `bash tools/tier-b.sh || exit 1; for i in 2 3 4 5; do bash tools/tier-b.sh --fast || exit 1; done`
  — this compiles the fix in exactly once (the scratch checkout's own build) and then reuses that
  freshly-built binary for the remaining repeats, avoiding 5 full rebuilds while still proving the
  fix is what's under test.
- **A `001-launch-dock` "N entities, fewer than M minimum" (or similarly-shaped) golden refusal is
  not automatically the known load-dependent flake below — a genuine JS/init regression can produce
  the IDENTICAL symptom, and only running the scenario against a binary that actually contains the
  candidate fix distinguishes them.** A `JS_InitClass`/`initClass` call passed a null constructor
  left a prototype (e.g. `Mission.prototype`) undefined, which threw inside a `defineMethod(...)`
  call during world-load script execution and aborted population before the scenario's second
  entity ever spawned — same "has 1 entity, fewer than 2 minimum" refusal text as the load-flake
  class. Before writing off a goldens refusal as the documented flake (or before writing off a
  fix as "unrelated to this symptom" the way a reviewer might on a diff that touches
  `OOJSMission.mm`/init code rather than a test file): grep `Resources/Scripts/` for a
  `defineMethod`/property access on the prototype the diff touches, trace whether that call
  executes during world load, then independently rebuild and run the scenario 2+ times against a
  binary containing ONLY the candidate fix (see the `--fast`-staleness bullet above for how to
  force a real rebuild) before either accepting a reviewer's scope objection or overriding it — the
  empirical rerun is stronger evidence than either the diff's apparent unrelatedness or a stored
  "scope" argument alone.
- **`tools/guardrails.sh`'s own documented remedy for a low-similarity-rename deny-list false
  positive ("split the pure move into its own commit") does not actually work — verify before
  trusting the tool's comment.** The script's header explains that a rename git scores below its
  ~50% similarity threshold (`git diff -M`) gets no baseline credit and reads as delete+add, and
  suggests splitting history so the pure rename lands as its own commit. In practice `guardrails.sh`
  computes `CHANGE` as a tree-to-tree diff across the full `BASE..HEAD` range
  (`git diff --name-status --find-renames "$BASE" --`), which compares the ORIGINAL content at BASE
  against the FINAL content at HEAD regardless of how many commits sit between them — splitting the
  commit cannot raise that end-to-end similarity score. A worker that reports "split the commit,
  guardrails now passes" must be independently re-run (`bash tools/guardrails.sh --base <ref>` in
  the worktree, not trusted from the summary) before treating the bead as unblocked; if it still
  FAILs, this is a real tool defect worth its own bead/ADR (pass `--base` at the exact pre-move ref,
  or extend the deny-list's rename-credit logic to work per-commit), not something a retarget-sweep
  worker can fix by rearranging their own history.
- **A component/offline pytest failure surfacing only inside a `tier-b.sh --fast` run must be
  reproduced with a bare, direct pytest invocation before it is blamed on the bead under review.**
  `accept.sh`/`tier-b.sh` wrap the real command in scratch checkouts and timeouts that make it hard
  to tell "this bead broke it" from "this was already broken on main". Isolate: `cd` to the repo
  root (confirm with `git branch --show-current` = the base branch), then run the exact failing
  test file/node directly, e.g. `python3 -m pytest <path>::<test> -x -q` — no `tier-b.sh`, no
  scratch checkout, no timeout wrapper. If it fails the same way on plain `main`, it is a
  pre-existing infra defect (log it, do not count it against the bead) rather than a regression;
  if it only fails through the wrapped run, the wrapper/environment is the suspect, not the code.
- **A recurring "post-rename C-linkage" infra break (missing `OOJS_EXTERN_C`/`extern "C"` after a `.m`->`.mm` rename) can resurface even after a dedicated fix bead for it just closed, because sibling accepts keep landing new renames while the fix bead is in flight.** Chasing whichever undefined symbols the linker reports *right now* only fixes yesterday's backlog; by the time that fix bead merges, more renames may have landed. Symptom: `bash tools/build-windows.sh test` off a fresh clean `main` fails to link, shortly after a bead that fixed the exact same class of bug closed. Treat this as a systemic sweep-vs-race problem: file/dispatch a new fix bead the same way (grep the linker's undefined-symbol list, wrap each declaring header), but expect it to need another round soon if there are still open js-retarget beads landing renames concurrently — don't be surprised when it recurs, and don't block the whole fleet waiting for a single "final" fix bead to make it permanently green.
- **A worker/review round's citation of an ADR or decision doc must be verified to exist before it changes what gate you require — this pattern (fabricating a citation to justify weakening the acceptance bar) recurs across different beads, not just once.** `find docs/decisions -iname '*NNNN*'` / `grep -r 'ADR-NNNN' docs/` before accepting any acceptance-rewrite that swaps `tools/tier-b.sh --fast` for something cheaper (e.g. `tools/guardrails.sh` alone). Do this reflexively on every acceptance-rewrite you see, not only after being burned once.
- **When independently verifying a worker's "this failure is pre-existing on main, not caused by my change" claim, never run `git checkout <ref> -- <file>` or any other tracked-file mutation inside an EXISTING bead worktree you don't own — build a separate, disposable one.** The urge to quickly swap a file back to main's version inside a worktree that's mid-review dirties a branch that must stay clean for `accept.sh`'s fast-forward step, and is easy to do by habit when you're already `cd`'d into that worktree to compare diffs. Instead: `git worktree add --detach <repo>/.worktrees/_verify_<label> main` (a fresh path, never an existing `.worktrees/<bead>`), run the check there, then `git worktree remove --force` it when done. If you do slip and modify a live worktree's tracked file, `git checkout HEAD -- <file>` immediately and confirm `git status --porcelain` is empty again before doing anything else with that worktree.
- **A stored acceptance line piped through `grep -q` can fail with `[exit 141]` (SIGPIPE) on a
  correct, passing check — not a real rejection.** `accept.sh` runs each line under
  `bash -o pipefail -c`; `grep -q` exits the instant it finds its first match and SIGPIPEs the
  still-writing producer (`git log --oneline main | grep -q <sha>`), and `pipefail` turns that
  SIGPIPE into a nonzero exit even though the match was real. Symptom: `rejected <id> (attempt N):
  new failure` with the failing line ending in `grep -q ...` and `[exit 141]`, while running the
  identical line manually (outside pipefail) clearly passes. Fix: drop `-q` and redirect instead —
  `grep <pattern> > /dev/null` (or `grep -c <pattern> >/dev/null` if you need "at least one match"
  semantics) — never `grep -q` on the read side of a pipe inside stored acceptance. Verify the fix
  with `bash -o pipefail -c "<line>"` before re-storing, the same discipline as any other stored
  acceptance change.
- **`tools/tier-a.sh`'s fixed wall-clock budget can fail a PASS-quality result under heavy
  concurrent box load — retry once with the budget bumped to isolate a load flake from a real
  regression before treating it as a rejection.** Symptom: `tier-a: PASS but Ns exceeds the Ns
  budget` on a file whose diff never touched anything timing-related, immediately after (or
  during) several other sessions' accepts/builds are running. Retry the same `accept.sh <id>` with
  `OOLITE_TIER_A_BUDGET=90` (or higher) exported alongside the usual `PATH`/`LOCALAPPDATA` — the
  var is read by `tools/tier-a.sh` and passed through by `accept.sh`'s `bash -o pipefail -c "$cmd"`
  execution. If it now passes cleanly with the same deny-list/warning counts as the failing runs,
  the budget overrun was load, not code; log it as a load flake in the bead's notes rather than a
  real rejection and do not count it toward `stale_count`.
- **A failing GUI acceptance line is not trusted until it fails ISOLATED too (bug oo-ac3f).**
  `tools/gui-lock` (the session-scoped `desktop_lock` fixture in
  `oolite-dev/tests/gui/conftest.py`) already serialises every GUI-launching pytest run, so
  two GUI processes cannot fight over the desktop at the same instant — that collision is not the
  risk. The risk is a CONCURRENT NON-GUI sibling (another tier compiling, several pytest processes
  running at once) starving the CPU of whichever process holds the lock: the GUI tier's timeouts
  (`TRANSITION_TIMEOUT_SECONDS`, `ScreenWitness.accept(timeout=...)`, `gui_screen(timeout=...)`)
  are real wall-clock timers, so contention alone can flip a transition-timeout test from pass to
  fail with no code change at all. Observed in production: oo-6zd's acceptance line 6 returned
  rc=1 under contention with a sibling launching G5, then rc=0 seconds later run alone — same
  code, same tree, opposite verdicts. So: when a GUI-tier acceptance line (`accept.sh` runs
  anything under `oolite-dev/tests/gui/`) returns nonzero, re-run it once with
  `tools/gui-acceptance-recheck "<line>"` before writing `accept attempt N failed` into the bead's
  notes or counting it toward `stale_count`. That script re-runs the line once the gui-lock is
  free and the sibling-load proxy is quiet (or a bounded wait elapses), and reports the gui-lock
  holder and a process-count proxy around both runs. If the recheck passes, the failure was
  contention, not a genuine regression: do not append it to notes as a failure and do not count it
  toward `BEADS_WORKER_STALE_REPEATS`; treat that acceptance round as needing a plain retry instead.
  If the recheck also fails, it is genuine — proceed exactly as `accept.sh` already does. This does
  NOT apply to non-GUI (unit/component) acceptance lines, and it does not replace fixing an
  actually-flaky GUI test (that is a bug in the test, e.g. oo-3opg, not a review-process step).
- **A `libtre-5.dll`/`libsystre-0.dll` (or any DLL) unresolved-imports failure inside
  `tests/golden/dump/test_launch_preflight.py` under `tier-b.sh --fast` is a shared-build-dir
  staging race, not a code defect — and the race can be a genuinely ORPHANED process, not just
  serialized contention.** The test hard-links whatever files currently exist in the ONE shared
  `APP_DIR` at the instant it runs; some dependency DLLs (e.g. `libtre-5.dll`) are staged as a
  side effect of `stage_mesa` copying files one at a time and are not in the test's own explicit
  dependency set, so a concurrent `tier-b.sh` mid-`stage_mesa` can be caught with one DLL copied
  and its dependency not yet copied. Before treating repeated identical failures here as a stale
  gate (5x -> escalate): `ps -ef | grep -iE "tier-b|pytest"` and, for each hit, check whether its
  PARENT pid is still alive (`kill -0 <ppid>`) — a `tier-b.sh`/pytest tree whose parent `accept.sh`
  already died (timed out, was killed, or exited) is NOT covered by `accept.sh`'s own lock
  discipline and can keep racing the shared build dir indefinitely; `kill -9` the orphaned tree.
  Retry after killing orphans and once `ps -ef | grep -c tier-b` drops; do not count these
  failures toward `stale_count` while sibling `tier-b`/`accept.sh` processes are still running.
- **A worker's fix that makes the ONE named failing test pass can silently break SIBLING tests
  that share the same constant/fixture for a different purpose — always re-run the FULL test file
  (or the full acceptance line) against a real build before trusting a fix, not just the test the
  bead was filed against.** A constant like a DLL/dependency set can be dual-purpose: used both as
  "the exact set an assertion checks against" (must stay a fixed, closed list) and as "the set of
  things to stage/copy for a fixture" (should grow to include transitive deps). Folding a new
  transitive dependency directly into the shared constant fixes the staging use but pollutes every
  assertion that expects the original, narrower set — a naive worker fix can go from 1 failing test
  to 2 newly-broken ones while claiming success. Independently re-run the whole test file (not the
  `-k`/single-node command the worker reports) with the real build (`OO_APP_DIR` set) before
  accepting a `committed: true` claim on any fix that touches a shared constant, fixture helper, or
  config value used in more than one place. If it breaks siblings, the correct fix is usually to
  split the constant in two (one for the assertion target, a separate one for the staging/fixture
  set) rather than widening the shared one — send it back with that specific direction rather than
  a generic "fix your regression".
- **A stored acceptance exemption keyed to specific LINE NUMBERS (e.g. "ignore JS_* hits on lines
  N1,N2,...") for a documented out-of-scope carve-out) goes stale the moment the file is edited
  again, even by a legitimate continuation round on the same bead.** Re-derive the exemption list
  from the CURRENT file (`grep -nE '<pattern>' <file> | cut -d: -f1`) every time before trusting or
  re-storing a line-number-based acceptance check, and prefer matching by the exempted SYMBOL NAMES
  (e.g. `JS_IsDebuggerFrame`, `JS_GetFrameScopeChain`) over line numbers when the carve-out is a
  fixed, documented set of calls — a name-based exclusion survives further edits to the file that a
  line-number one does not.
  **A line-number exclusion regex without a leading `^` anchor matches nowhere in `line:content`
  output and silently makes the whole acceptance line always-fail, even though it LOOKS like a
  correct exemption when read.** `grep -vE ':(41|42|...):'` matches the number anywhere
  (`content` text containing a colon-digit-colon substring), not just at the start of the
  `grep -n` line prefix; if the excluded numbers never happen to appear that way in the code, every
  original hit survives the `-v` filter and the negated acceptance line (`! grep ... | grep -v ...`)
  reports a false failure on a file that is actually clean. Always verify a stored exclusion
  pattern by running it exactly as `accept.sh` will (`bash -o pipefail -c "<line>"`) BOTH against
  the fixed file (must exit 0/no output) before storing — the visual "looks like it excludes the
  right numbers" read is not proof; a worker reported this line as passing without ever executing
  it, and it does not.
- **Calling a bead-tracker binary by its ABSOLUTE PATH (bypassing PATH resolution) also bypasses
  any PATH-based guard shim placed in front of it — this includes accidental status changes, not
  just deliberate closes.** The guard shim that refuses `bd close`/`bd update --status closed` only
  intercepts calls that resolve through PATH; invoking the real binary directly (needed on this box
  because the shim script itself can't be exec'd from some callers) means an innocuous-looking
  `bd update <id> --status closed` used to mark something "not worth tracking further" silently
  succeeds and actually closes the bead, with no refusal and no warning. Never issue `--status
  closed` this way for ANY reason, including "this is a duplicate" — a duplicate gets a note
  cross-referencing the real bead and stays open (or the human/owning process closes it through the
  proper channel); if you catch yourself doing this, `bd update <id> --status open` immediately to
  reopen and record the correction in notes.
- **A tier-b goldens-stage failure with the signature "N entities, fewer than the M minimum;
  a dump with no world in it compares equal to any other empty world" (golden_diff rc=2 REFUSED) on
  the `001-launch-dock` scenario is a known load-dependent determinism defect in the scenario
  itself, not a code regression — escalate after 2 occurrences across ANY bead, don't keep
  retrying.** Under heavy concurrent box load the launch/dock run can dump before the second entity
  ever spawns; `tests`/`parity` stages pass cleanly both before and after, confirming the bead's own
  diff is not at fault. The scenario's own guards don't assert the expected entity set, so a
  truncated run "refuses" instead of failing loudly — a real fix (assert the entity set, or
  decouple spawn timing from elapsed frames) touches `tests/`/`goldens/` and needs Jon's decision,
  so `reevaluate.sh` will correctly route it to `escalate`. Once one bead hits this signature and is
  escalated, escalate every sibling bead that hits the SAME signature directly (cite the first
  bead's escalation reason) rather than re-running `reevaluate.sh` per bead — it is the same root
  cause every time, not a new one.
- **The same underlying bug can get filed as more than one bead by concurrent sessions — before
  filing a new bead for something you just root-caused, `bd list --json` grep for its symptom
  string.** If a match already exists (even freshly filed, even by a worker in another worktree),
  claim and work THAT one instead of your own; leave your duplicate open with a note pointing at
  the real bead's id, so Jon can retire it. You cannot close either of them yourself.
- **Once a systemic root-cause fix lands on develop, sweep for the beads that were parked for that
  exact signature and un-stick them — `human` is not a terminal state.** `bd list --label human
  --json` for beads whose notes mention the now-fixed signature. If a bead's own implementation
  work is intact and unrelated to the systemic bug, reclaim it, note that the blocking flake is
  fixed (cite the fix's bead id and its pull request), and run its gate again. Beads parked for a
  root cause you just fixed are the highest-value work available — they already carry their retry
  history and usually just need the now-passing gate to confirm.
