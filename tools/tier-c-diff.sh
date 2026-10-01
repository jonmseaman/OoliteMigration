#!/usr/bin/env bash
#
# tools/tier-c-diff.sh -- differential run of goldens and corpus across the two JS backends
# (Phase 1 seam 1.5a, bead oo-2t6).
#
#     tools/tier-c-diff.sh                      # run both backends, write the divergence report
#     tools/tier-c-diff.sh --report-only         # skip both runs, just re-render from a prior run
#     tools/tier-c-diff.sh --out DIR             # where to write logs and the report (default:
#                                                 #   a private tmp dir; kept on any divergence)
#     tools/tier-c-diff.sh --sm-app-dir DIR      # override the SpiderMonkey build's app dir
#     tools/tier-c-diff.sh --quickjs-app-dir DIR # override the QuickJS-ng build's app dir
#
# WHAT THIS IS, AND WHAT IT IS NOT.
#
# tools/tier-c.sh already runs the goldens and the full Tier 1 corpus; this script does not
# duplicate that logic. It runs `tools/tier-c.sh --backend=sm --only goldens,corpus` and
# `tools/tier-c.sh --backend=quickjs --only goldens,corpus` -- one per engine, each against its
# own build directory (bead oo-2t6 wired --backend into tier-c.sh precisely so this composition is
# possible) -- and DIFFS what each produced: golden dump JSON, field by field, via the same
# tests/golden/golden_diff.py the goldens stage itself trusts, and corpus per-group verdicts, via
# each run's own results.json.
#
# THE OUTPUT CONTRACT (this bead's DONE WHEN): "Report lists every golden/corpus divergence with
# the first differing line." The report below does exactly that -- one line per divergent golden
# scenario naming its first `golden_diff.py` DIFFERENCE line, and one line per corpus group whose
# verdict differs between backends, naming the two verdicts. A run with NO divergence still
# produces a report; it says so explicitly, distinct from a report that never ran (see ANTI-VACUITY
# below).
#
# WHY THIS IS ITS OWN SCRIPT AND NOT AN EIGHTH tier-c.sh STAGE. Running BOTH backends means TWO
# builds and TWO full corpus/golden passes -- roughly double tier-c.sh's own 15-20 minutes, and it
# needs the QuickJS-ng backend actually built (a separate build directory, `-Djs_backend=quickjs`),
# which most callers of tier-c.sh do not have and should not be forced to build. tier-c.sh's own
# budget (2400 s) assumes ONE backend; folding a second build and pass into it would blow that
# budget for everyone who only wants the merge gate. This script is the seam's own top-level tool,
# composing tier-c.sh rather than re-implementing its stages.
#
# ANTI-VACUITY. A differential that "found nothing" is satisfiable by a run that did nothing --
# comparing two golden sets neither of which has any entries reports zero divergences and looks
# identical to a real, clean pass. So this script requires, and reports, POSITIVE counts on both
# sides: how many golden scenarios were actually dumped and compared per backend, and how many
# corpus groups were actually checked per backend, each against the same floors tier-c.sh itself
# enforces (GOLDEN_FLOOR, CORPUS_FLOOR) -- a backend run that produced fewer than the floor is a
# FAILURE of this script, not a report of "0 divergences".
set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

die() { printf 'tier-c-diff: %s\n' "$*" >&2; exit 2; }

OUT=""
REPORT_ONLY=0
SM_APP_DIR="${OO_SM_APP_DIR:-}"
QUICKJS_APP_DIR="${OO_QUICKJS_APP_DIR:-}"
GOLDEN_FLOOR="${OOLITE_TIER_C_GOLDEN_FLOOR:-2}"
CORPUS_FLOOR="${OOLITE_TIER_C_CORPUS_FLOOR:-36}"

while [ $# -gt 0 ]; do
  case "$1" in
    --out)              OUT="${2:?--out needs a directory}"; shift ;;
    --out=*)             OUT="${1#--out=}" ;;
    --report-only)        REPORT_ONLY=1 ;;
    --sm-app-dir)         SM_APP_DIR="${2:?--sm-app-dir needs a path}"; shift ;;
    --sm-app-dir=*)       SM_APP_DIR="${1#--sm-app-dir=}" ;;
    --quickjs-app-dir)    QUICKJS_APP_DIR="${2:?--quickjs-app-dir needs a path}"; shift ;;
    --quickjs-app-dir=*)  QUICKJS_APP_DIR="${1#--quickjs-app-dir=}" ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

[ -n "$OUT" ] || OUT="$(mktemp -d "${TMPDIR:-/tmp}/tier-c-diff-$$-XXXXXX")" || die "cannot create the output directory"
mkdir -p "$OUT"
OUT_NATIVE="$(native "$OUT")"

PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || die "no python on PATH"

run_backend() {
  # run_backend <label> <backend-flag> <app-dir-override>
  local label="$1" flag="$2" app_override="$3"
  local log="$OUT/tier-c-$label.log" rc=0
  printf '==> running backend %s (tools/tier-c.sh --backend=%s --only goldens,corpus)\n' "$label" "$flag"
  # Through env: a ${...:+VAR=...} expansion ahead of an assignment turns the assignment into a
  # command name (exit 127 on the first real run, bead oo-1gc.6).
  ( cd "$REPO_ROOT" \
    && env ${app_override:+OO_APP_DIR="$(native "$app_override")"} \
       OOLITE_TIER_C_KEEP=1 \
       bash "$HERE/tier-c.sh" --backend="$flag" --only goldens,corpus ) \
    > "$log" 2>&1 || rc=$?
  printf 'tier-c-diff: backend %s exited %d; log %s\n' "$label" "$rc" "$(native "$log")"
  return "$rc"
}

# ---------------------------------------------------------------------------------------------
# 1. RUN BOTH BACKENDS (unless --report-only, which re-uses a prior --out).
# ---------------------------------------------------------------------------------------------

SM_LOG="$OUT/tier-c-sm.log"
QJS_LOG="$OUT/tier-c-quickjs.log"
SM_RC=0
QJS_RC=0

if [ "$REPORT_ONLY" = 1 ]; then
  [ -f "$SM_LOG" ] || die "--report-only was given but $(native "$SM_LOG") does not exist; run without --report-only first, or point --out at a kept run"
  [ -f "$QJS_LOG" ] || die "--report-only was given but $(native "$QJS_LOG") does not exist"
else
  run_backend sm sm "$SM_APP_DIR"; SM_RC=$?
  run_backend quickjs quickjs "$QUICKJS_APP_DIR"; QJS_RC=$?
fi

# ---------------------------------------------------------------------------------------------
# 2-4. DIFF THE GOLDEN DUMPS AND THE CORPUS, AND WRITE THE REPORT -- in ONE python process.
#
# Each run root's golden dumps ("$RUN_ROOT/$name.json", minus the diff-*/ev-* companions) are
# compared pairwise with tests/golden/golden_diff.py (the tool the goldens stage itself trusts),
# each run's corpus results.json (named by "results: <path>" in "$RUN_ROOT/corpus.log") by group
# name + verdict, against the GOLDEN_FLOOR / CORPUS_FLOOR anti-vacuity floors above; the report
# goes to "$OUT/divergence-report.md" and to stdout.
#
# WHY ONE PROCESS (bead oo-3rb.349). This used to be bash: a cygpath/grep/sed/wc/python spawn for
# nearly every line, ~60 for a two-scenario fixture. An MSYS spawn costs 1-2 s on a loaded machine,
# so --report-only took >60 s under tier-b's concurrent pytest shards and tools/test_tier_c_diff.py
# timed out twice in the Phase 2 exit gate. tools/tier_c_diff_report.py does the same comparison,
# with the same output and exit codes (0 green, 1 divergence or a failed backend, 2 refusal), in a
# single interpreter, so its cost no longer scales with process spawns.
# ---------------------------------------------------------------------------------------------

exec "$PY" "$(native "$HERE/tier_c_diff_report.py")" --out "$OUT_NATIVE" \
  --sm-rc "$SM_RC" --quickjs-rc "$QJS_RC" \
  --golden-floor "$GOLDEN_FLOOR" --corpus-floor "$CORPUS_FLOOR"
