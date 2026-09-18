#!/usr/bin/env bash
# oo-5ggu: prove the stored golden for a scenario still reproduces across TWO INDEPENDENT runs.
#
# "Independent" is load-bearing and is what golden_diff.py enforces for us: two separate game
# PROCESSES, two separate output files, neither of them a link to the other (golden_diff checks
# st_dev/st_ino, so a hardlink is not a second run). Each run is diffed against the STORED golden
# rather than against each other, because two runs agreeing with one another while both disagreeing
# with the golden is a regression, not a pass.
#
# PRIVATE PORT AND PRIVATE APP. Runs go through tests/golden/dump/private_port_dump.py, not
# run_dump.py directly: the game DIALS OUT to the port named in debugConfig.plist, so on this
# five-agent box a run on the default 8563 can be accepted - and quit seconds in - by a sibling's
# console while still exiting rc=0 with an error-free log (fleet learnings oo-gla, oo-het). That is
# a vacuous pass and this gate must not be able to produce one.
#
# APP DIR. Worktrees and accept.sh's throwaway checkout contain no build, so the app dir defaults
# to the MAIN checkout's, overridable with OO_APP_DIR (bead oo-ae9). It is only ever READ: the
# staging is junctions and hard links into a scratch dir, so this is safe to run while other
# agents are launching the same build.
set -euo pipefail
export PATH=/ucrt64/bin:$PATH   # else the loader kills oolite.exe with 3221225781 and no log

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCENARIO="${1:-001}"
PLATFORM="${OO_GOLDEN_PLATFORM:-windows-x64}"
APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"
GOLDEN="$REPO_ROOT/goldens/$PLATFORM/$SCENARIO/state.json"

[ -d "$APP_DIR" ] || { echo "no Oolite build at $APP_DIR (set OO_APP_DIR)" >&2; exit 1; }
[ -f "$GOLDEN" ]  || { echo "no stored golden at $GOLDEN" >&2; exit 1; }

PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)
WORK="${OO_GOLDEN_WORK:-${LOCALAPPDATA:-/tmp}/Temp/oo5ggu-reproduce-$$}"
mkdir -p "$WORK"
NWORK="$(cygpath -m "$WORK")"
NGOLDEN="$(cygpath -m "$GOLDEN")"
trap 'rm -rf "$WORK"' EXIT

rc=0
for run in run1 run2; do
  t0=$SECONDS
  "$PY" "$(cygpath -m "$REPO_ROOT/tests/golden/dump/private_port_dump.py")" \
      --app-dir "$APP_DIR" --work-dir "$NWORK/$run" --out "$NWORK/$run.json"
  echo "  $run: dumped in $(( SECONDS - t0 ))s, $(wc -c < "$WORK/$run.json") bytes"
done

# The two dumps must be two different files on disk before either verdict means anything.
if [ "$(md5sum < "$WORK/run1.json")" != "$(md5sum < "$WORK/run2.json")" ]; then
  echo "run1 and run2 disagree with EACH OTHER: the scenario is not reproducible on this build" >&2
  rc=1
fi

for run in run1 run2; do
  echo "==> $run vs stored golden"
  # rc=2 (REFUSED) is deliberately NOT treated as a pass: see golden_diff.py's exit codes.
  if ! "$PY" "$(cygpath -m "$REPO_ROOT/tests/golden/golden_diff.py")" \
        "$NGOLDEN" "$NWORK/$run.json" \
        --label-left "goldens/$PLATFORM/$SCENARIO/state.json" --label-right "$run"; then
    echo "  $run did NOT reproduce the stored golden" >&2
    rc=1
  fi
done

if [ $rc -eq 0 ]; then
  echo "PASS: scenario $SCENARIO reproduced by 2 independent runs of $APP_DIR"
fi
exit $rc
