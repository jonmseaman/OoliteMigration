#!/usr/bin/env bash
#
# The SCHEDULED runner: nightly Tier C and weekly Tier 3 corpus on the fleet machine.
# Phase 0 exit-gate boxes 30 and 32 (docs/phases/0-safety-net.md): the corpus is
# "per-commit / nightly / weekly" and the GUI tier runs "by Tier C and nightly".
# ADR-0016 (no forge): there is no hosted scheduler, so the schedule is a Windows scheduled
# task on this machine, registered by tools/install-scheduled-tasks.ps1, and this is the
# script that task runs.
#
#     tools/nightly.sh                    # tier-c (the nightly job), the default
#     tools/nightly.sh tier-c             # the same, named
#     tools/nightly.sh corpus-tier3       # the weekly job: ALL 813 corpus expansions
#     tools/nightly.sh tier-c --dry-run   # resolve and print the plan, run nothing, log nothing
#     tools/nightly.sh tier-c -- --list   # anything after `--` goes to the runner verbatim
#
# The `--` pass-through exists so this wrapper's own logging and verdict path can be exercised
# without waiting for a 20-minute tier: `tools/nightly.sh tier-c -- --list` runs in ~2 s and
# proves the anti-vacuity marker check below is NOT vacuous, because tier-c --list exits 0 while
# printing no `tier-c: GREEN` line, and this wrapper correctly records that as RED. A wrapper
# whose failure path is only ever exercised at 02:00 is a wrapper nobody has tested.
#
# KNOWN, PRE-EXISTING, AND NOT THIS SCRIPT'S BUG: `tools/tier-c.sh --only <stage>` and `--skip`
# currently die with `tier-c: no such stage 'jsapi'` on this box for every stage name, including
# valid ones. Measured cause: tier-c.sh's validation loop is `all_stage_names | grep -qx "$want"`
# under `set -o pipefail`, and grep -q exits on first match, so the still-writing left side dies
# on SIGPIPE and the pipeline reports 141 -- exactly the trap bead oo-j4u lost two acceptances
# to. Reproduced in isolation: pipefail rc=141, without pipefail rc=0. The scheduled jobs do not
# use --only, so they are unaffected; filed as a separate finding rather than fixed here.
#
# WHAT THIS ADDS OVER RUNNING tools/tier-c.sh BY HAND, and it is deliberately only three things:
#
#   1. A DATED LOG under build/nightly/, kept. build/ is gitignored (.gitignore:1), so a 02:00
#      run can never dirty the shared checkout and block accept.sh's fast-forward for the whole
#      fleet (the failure bead oo-4vdc measured from scratch files left in the repo root).
#   2. A ONE-LINE SUMMARY appended to docs/fleet/NIGHTLY.md, so the history of the schedule is
#      readable without opening a month of logs.
#   3. A VERDICT THAT IS NOT rc=0. Each job asserts a POSITIVE marker its runner prints only
#      after really finishing -- `tier-c: GREEN` for Tier C, the corpus report header plus a
#      non-zero expansion count for Tier 3. An exit status alone is satisfiable by a run that
#      died before it did anything (bead oo-het: a dead game launch exits 0 with no ERROR
#      lines), and a scheduled job nobody watches is exactly where a vacuous green survives.
#
# ------------------------------------------------------------------------------------------
# THIS SCRIPT DOES NOT TAKE tools/gui-lock, AND THAT IS THE POINT, NOT AN OMISSION
# ------------------------------------------------------------------------------------------
#
# It runs Tier C exactly the way Tier C is run today, and Tier C takes the desktop lock ITSELF,
# per stage, with `gui-lock run -- ...`: tools/tier-c.sh's asan stage wraps the sanitized launch
# in it, and its gui stage delegates to tools/gui-tier.sh, whose pytest session takes the lock in
# its own desktop_lock fixture. tools/gui-lock is an EXCLUSIVE mkdir mutex, so a wrapper that
# held it around the whole tier would block those stages against their own parent for the full
# acquire timeout and then fail -- the deadlock tools/check-desktop-lock.sh warns about for
# tests/golden/golden_run.py and upstream/oolite/tests/component/console.py. The lock belongs to
# whoever decides how many games run at once, and inside Tier C that is Tier C.
#
# Same reasoning for the weekly job: tools/tier-c.sh's corpus stage runs tools/corpus.sh with no
# lock, and tools/corpus.sh serialises its own launches, so the weekly tier3 run is invoked the
# same way. If either of those ever starts needing the foreground, the lock goes in THERE, next
# to the launch, not in this wrapper.
#
# ------------------------------------------------------------------------------------------
# THE SUMMARY FILE IS TRACKED, SO THE RUN LEAVES ONE ADDED LINE IN THE CHECKOUT
# ------------------------------------------------------------------------------------------
#
# docs/fleet/NIGHTLY.md is in git, so appending to it makes the working tree dirty by exactly
# one line, and accept.sh refuses to fast-forward a dirty root. That is a deliberate trade: the
# schedule's history is worth carrying in the repo, and one line is trivially committable. The
# run says so on its own last line, with the command to commit it. Point OO_NIGHTLY_SUMMARY at a
# path under build/ to opt out entirely (the log is still written).
set -u -o pipefail

# --- Re-exec into the UCRT64 shell ---------------------------------------------------------
#
# Identical to tools/tier-c.sh and tools/setup-windows.sh, and load-bearing HERE above all: the
# Windows Task Scheduler starts this from a bare process with no MSYS environment at all, so
# without the re-exec the job would run in whatever shell happened to be found and die inside
# the build with two empty diagnostics (bead oo-djn) or with 0xC0000135 after ~116 s because
# /ucrt64/bin is not on PATH (bead oo-gla). MSYS2_BASH's usual default does not exist on this
# box -- MSYS2 is the scoop package -- so the cygpath fallback is the branch that fires here.
MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ ! -x "$MSYS2_BASH" ] && command -v cygpath >/dev/null 2>&1; then
  _root="$(cygpath -m / 2>/dev/null || true)"
  [ -n "$_root" ] && [ -x "$_root/usr/bin/bash.exe" ] && MSYS2_BASH="$_root/usr/bin/bash.exe"
fi
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OOLITE_NIGHTLY_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  echo "==> MSYSTEM is '${MSYSTEM:-unset}'; re-executing under MSYS2 UCRT64"
  export OOLITE_NIGHTLY_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi
if [ -d /ucrt64/bin ]; then export PATH="/ucrt64/bin:$PATH"; fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

LOG_DIR="${OO_NIGHTLY_LOG_DIR:-$REPO_ROOT/build/nightly}"
SUMMARY="${OO_NIGHTLY_SUMMARY:-$REPO_ROOT/docs/fleet/NIGHTLY.md}"
STATE_DIR="${OO_NIGHTLY_STATE_DIR:-$LOG_DIR/state-tier3}"

die()  { printf 'nightly: %s\n' "$*" >&2; exit 2; }
step() { printf '==> %s\n' "$*"; }

# --- Arguments -----------------------------------------------------------------------------

JOB=""; DRY=0; EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    tier-c|corpus-tier3) [ -z "$JOB" ] || die "two jobs given ('$JOB' and '$1'); run one per invocation"; JOB="$1" ;;
    --dry-run) DRY=1 ;;
    --) shift; EXTRA=("$@"); break ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument '$1' (jobs: tier-c, corpus-tier3; try --help)" ;;
  esac
  shift
done
JOB="${JOB:-tier-c}"

# The job table: ONE declaration of what each job runs, what it is called in the summary, and
# the POSITIVE marker its output must carry. --dry-run prints exactly this, so the plan that is
# printed and the plan that runs cannot drift.
case "$JOB" in
  tier-c)
    LABEL="tier-c"
    DESC="the full Tier C merge gate (tools/tier-c.sh)"
    CMD=(bash "$HERE/tier-c.sh")
    MARKER='^tier-c: GREEN'
    MARKER_WHY="tier-c prints 'tier-c: GREEN in <n>s' only after every selected stage completed"
    ;;
  corpus-tier3)
    LABEL="corpus-tier3"
    DESC="the WEEKLY corpus: tools/corpus.sh tier3, all 813 expansions, resumable"
    CMD=(bash "$HERE/corpus.sh" tier3 --state "$(native "$STATE_DIR")")
    MARKER='=== OXP corpus load report: [0-9]+ expansion\(s\) ==='
    MARKER_WHY="corpus.sh renders its report header only after the tier ran; the count is checked to be non-zero below"
    ;;
  *) die "internal: no such job '$JOB'" ;;
esac
[ "${#EXTRA[@]}" -eq 0 ] || CMD+=("${EXTRA[@]}")

[ -f "$HERE/tier-c.sh" ] || die "tools/tier-c.sh is missing; there is no tier for the schedule to run"
[ -f "$HERE/corpus.sh" ] || die "tools/corpus.sh is missing; there is no corpus for the schedule to run"

STAMP="$(date '+%Y%m%d-%H%M%S')"
LOG="$LOG_DIR/$LABEL-$STAMP.log"

if [ "$DRY" = 1 ]; then
  printf 'nightly: job %s -- %s\n' "$LABEL" "$DESC"
  printf 'nightly: command  %s\n' "${CMD[*]}"
  printf 'nightly: log      %s\n' "$(native "$LOG")"
  printf 'nightly: summary  %s\n' "$(native "$SUMMARY")"
  printf 'nightly: marker   %s\n' "$MARKER"
  printf 'nightly: dry run -- nothing was executed, no log written, no summary appended\n'
  exit 0
fi

mkdir -p "$LOG_DIR" || die "cannot create the log directory $(native "$LOG_DIR")"

# --- Run -------------------------------------------------------------------------------------
#
# tee so an operator watching the task's own window sees progress, and the kept log is the same
# bytes. pipefail is set at the top, but tee's status is the one bash would report, so the rc is
# read out of PIPESTATUS explicitly.
step "nightly $LABEL: $DESC"
step "log $(native "$LOG")"
START_EPOCH="$(date '+%s')"
STARTED="$(date '+%Y-%m-%d %H:%M:%S')"
{
  printf '# nightly %s, started %s\n' "$LABEL" "$STARTED"
  printf '# command: %s\n' "${CMD[*]}"
  printf '# repo:    %s\n\n' "$(native "$REPO_ROOT")"
} > "$LOG"

rc=0
( cd "$REPO_ROOT" && "${CMD[@]}" ) 2>&1 | tee -a "$LOG"
rc="${PIPESTATUS[0]}"
WALL=$(( $(date '+%s') - START_EPOCH ))

# --- The verdict ------------------------------------------------------------------------------
#
# rc=0 is necessary and NOT sufficient. The marker is the positive evidence that the runner
# reached its own end; without it a job that exited 0 having done nothing would be recorded as a
# green night, which is the one failure a schedule nobody watches cannot recover from.
VERDICT="GREEN"; NOTE=""
if [ "$rc" -ne 0 ]; then
  VERDICT="RED"
  NOTE="rc=$rc; $(grep -m1 -E 'FAIL \(stage [a-z-]+\)|^tier-c: |NOTLOADED|failing' "$LOG" | tail -1 | cut -c1-120)"
elif ! grep -qE "$MARKER" "$LOG"; then
  VERDICT="RED"
  NOTE="rc=0 but the log carries no completion marker -- $MARKER_WHY"
  rc=1
elif [ "$LABEL" = "corpus-tier3" ]; then
  # The corpus report header is present; assert it counted something. A run that staged nothing
  # renders "0 expansion(s)" and exits 0 (bead oo-het measured 35 of 36 silently never staged).
  n="$(grep -oE '=== OXP corpus load report: [0-9]+ expansion' "$LOG" | tail -1 | grep -oE '[0-9]+' || echo 0)"
  if [ "${n:-0}" -lt 1 ]; then
    VERDICT="RED"; rc=1
    NOTE="the corpus report counted ${n:-0} expansion(s); a tier that checked nothing is not a pass"
  else
    NOTE="$n expansion(s) checked"
  fi
fi
[ -n "$NOTE" ] || NOTE="$(grep -m1 -E "$MARKER" "$LOG" | cut -c1-120)"

# --- The one-line summary ----------------------------------------------------------------------

mkdir -p "$(dirname "$SUMMARY")" 2>/dev/null || true
if [ ! -f "$SUMMARY" ]; then
  {
    printf '# Nightly and weekly schedule log\n\n'
    printf 'One line per scheduled run, appended by `tools/nightly.sh`.\n\n'
    printf '| started | job | verdict | rc | wall | log | note |\n'
    printf '|---|---|---|---|---|---|---|\n'
  } > "$SUMMARY"
fi
printf '| %s | %s | %s | %s | %ss | `%s` | %s |\n' \
  "$STARTED" "$LABEL" "$VERDICT" "$rc" "$WALL" \
  "build/nightly/$(basename "$LOG")" "${NOTE//|/;}" >> "$SUMMARY"

printf '\nnightly: %s %s in %ss (rc=%s)\n' "$LABEL" "$VERDICT" "$WALL" "$rc"
printf 'nightly: log     %s\n' "$(native "$LOG")"
printf 'nightly: summary %s (one line appended -- commit it, or accept.sh cannot fast-forward a dirty root:\n' "$(native "$SUMMARY")"
printf '                 git add docs/fleet/NIGHTLY.md && git commit -m "nightly %s %s")\n' "$LABEL" "$STARTED"
exit "$rc"
