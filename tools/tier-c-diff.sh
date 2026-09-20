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
  ( cd "$REPO_ROOT" \
    && ${app_override:+OO_APP_DIR="$(native "$app_override")"} \
       OOLITE_TIER_C_KEEP=1 \
       bash "$HERE/tier-c.sh" --backend="$flag" --only goldens,corpus ) \
    > "$log" 2>&1 || rc=$?
  printf 'tier-c-diff: backend %s exited %d; log %s\n' "$label" "$rc" "$(native "$log")"
  return "$rc"
}

# The run root each tier-c.sh invocation KEEPS on disk (OOLITE_TIER_C_KEEP=1 above forces it to
# keep the root even on a clean pass, which this script needs -- it reads the dumps and the corpus
# results.json back out of it), reported on its own "logs kept at" line.
run_root_of() {
  local log="$1"
  grep -m1 'logs kept at' "$log" | sed -E 's/^.*logs kept at ([^ ]+).*$/\1/'
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

SM_ROOT="$(run_root_of "$SM_LOG")"
QJS_ROOT="$(run_root_of "$QJS_LOG")"

[ -n "$SM_ROOT" ] && [ -d "$SM_ROOT" ] \
  || die "could not find the SpiderMonkey run's kept root from $(native "$SM_LOG"); the run may have failed before reaching goldens/corpus. Tail: $(tail -5 "$SM_LOG" 2>/dev/null)"
[ -n "$QJS_ROOT" ] && [ -d "$QJS_ROOT" ] \
  || die "could not find the QuickJS-ng run's kept root from $(native "$QJS_LOG"); the run may have failed before reaching goldens/corpus. Tail: $(tail -5 "$QJS_LOG" 2>/dev/null)"

printf 'tier-c-diff: sm run root      %s\n' "$(native "$SM_ROOT")"
printf 'tier-c-diff: quickjs run root %s\n' "$(native "$QJS_ROOT")"

# ---------------------------------------------------------------------------------------------
# 2. DIFF THE GOLDEN DUMPS: every scenario name present under EITHER run root's *.json dumps,
#    compared with tests/golden/golden_diff.py (the same tool the goldens stage itself trusts).
# ---------------------------------------------------------------------------------------------

REPORT="$OUT/divergence-report.md"
DIFF_LOG_DIR="$OUT/golden-diffs"
mkdir -p "$DIFF_LOG_DIR"

golden_names() {
  # The dump files tier-c.sh's goldens stage writes are "$RUN_ROOT/$name.json" for every
  # scenario under goldens/<platform>; list them by stripping the .json off the basename, and
  # EXCLUDE the diff-*/ev-*/cfg-*/out-* companions tier-c.sh also drops in that same directory.
  local root="$1"
  ( cd "$root" && ls -1 -- *.json 2>/dev/null | sed 's/\.json$//' \
      | grep -vE '^(diff-|ev-)' )
}

SM_NAMES="$(golden_names "$SM_ROOT" | sort)"
QJS_NAMES="$(golden_names "$QJS_ROOT" | sort)"
ALL_NAMES="$(printf '%s\n%s\n' "$SM_NAMES" "$QJS_NAMES" | sort -u | sed '/^$/d')"

SM_GOLDEN_COUNT="$(printf '%s\n' "$SM_NAMES" | sed '/^$/d' | wc -l | tr -d ' ')"
QJS_GOLDEN_COUNT="$(printf '%s\n' "$QJS_NAMES" | sed '/^$/d' | wc -l | tr -d ' ')"

# ANTI-VACUITY: a differential over a golden set that never ran (floor unmet on EITHER side) is
# not a differential; it is two empty sets compared and reported as "0 divergences".
[ "${SM_GOLDEN_COUNT:-0}" -ge "$GOLDEN_FLOOR" ] \
  || die "the SpiderMonkey run produced only $SM_GOLDEN_COUNT golden dump(s), fewer than the floor of $GOLDEN_FLOOR; a differential over an empty set is vacuous"
[ "${QJS_GOLDEN_COUNT:-0}" -ge "$GOLDEN_FLOOR" ] \
  || die "the QuickJS-ng run produced only $QJS_GOLDEN_COUNT golden dump(s), fewer than the floor of $GOLDEN_FLOOR; a differential over an empty set is vacuous"

GOLDEN_ROWS=()
GOLDEN_DIVERGENT=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  local_sm="$SM_ROOT/$name.json"
  local_qjs="$QJS_ROOT/$name.json"
  if [ ! -f "$local_sm" ]; then
    GOLDEN_ROWS+=("$name | MISSING on sm | present on quickjs")
    GOLDEN_DIVERGENT=$(( GOLDEN_DIVERGENT + 1 ))
    continue
  fi
  if [ ! -f "$local_qjs" ]; then
    GOLDEN_ROWS+=("$name | present on sm | MISSING on quickjs")
    GOLDEN_DIVERGENT=$(( GOLDEN_DIVERGENT + 1 ))
    continue
  fi
  dlog="$DIFF_LOG_DIR/$name.log"
  drc=0
  "$PY" "$(native "$REPO_ROOT/tests/golden/golden_diff.py")" \
    "$(native "$local_sm")" "$(native "$local_qjs")" \
    --label-left "sm/$name" --label-right "quickjs/$name" \
    > "$dlog" 2>&1 || drc=$?
  case "$drc" in
    0) : ;;
    1)
      first="$(grep -m1 '^  ' "$dlog" || true)"
      GOLDEN_ROWS+=("$name | DIFFERS | first: ${first:-<no line captured>}")
      GOLDEN_DIVERGENT=$(( GOLDEN_DIVERGENT + 1 ))
      ;;
    *)
      reason="$(grep -m1 '^REFUSED' "$dlog" || echo "refused (rc=$drc)")"
      GOLDEN_ROWS+=("$name | REFUSED | $reason")
      GOLDEN_DIVERGENT=$(( GOLDEN_DIVERGENT + 1 ))
      ;;
  esac
done <<< "$ALL_NAMES"

# ---------------------------------------------------------------------------------------------
# 3. DIFF THE CORPUS: results.json under each run root (written by corpus.sh tier1's
#    oxp_load_check.py --json), by group name + verdict.
# ---------------------------------------------------------------------------------------------

find_results_json() {
  # tools/corpus.sh's cmd_tier1 writes results.json under a work dir it prints as
  # "results: <path>" in its own log, which tier-c.sh's corpus stage captures at
  # "$RUN_ROOT/corpus.log". Read the path out of THAT rather than guessing a work dir layout the
  # corpus tool owns and may change.
  local corpus_log="$1"
  grep -m1 '^results: ' "$corpus_log" | sed 's/^results: //'
}

SM_CORPUS_LOG="$SM_ROOT/corpus.log"
QJS_CORPUS_LOG="$QJS_ROOT/corpus.log"
[ -f "$SM_CORPUS_LOG" ] || die "no corpus.log under $(native "$SM_ROOT"); the sm run's corpus stage did not leave the evidence this script depends on"
[ -f "$QJS_CORPUS_LOG" ] || die "no corpus.log under $(native "$QJS_ROOT"); the quickjs run's corpus stage did not leave the evidence this script depends on"

SM_RESULTS="$(find_results_json "$SM_CORPUS_LOG")"
QJS_RESULTS="$(find_results_json "$QJS_CORPUS_LOG")"
[ -n "$SM_RESULTS" ] && [ -f "$SM_RESULTS" ] \
  || die "could not find the sm corpus run's results.json (parsed '$SM_RESULTS' from $(native "$SM_CORPUS_LOG"))"
[ -n "$QJS_RESULTS" ] && [ -f "$QJS_RESULTS" ] \
  || die "could not find the quickjs corpus run's results.json (parsed '$QJS_RESULTS' from $(native "$QJS_CORPUS_LOG"))"

CORPUS_ROWS_FILE="$OUT/corpus-rows.tsv"
"$PY" - "$SM_RESULTS" "$QJS_RESULTS" "$CORPUS_ROWS_FILE" "$CORPUS_FLOOR" <<'PYEOF'
import json, sys

sm_path, qjs_path, out_path, floor = sys.argv[1:5]
floor = int(floor)

with open(sm_path, encoding="utf-8") as fh:
    sm = json.load(fh)
with open(qjs_path, encoding="utf-8") as fh:
    qjs = json.load(fh)

# ANTI-VACUITY: same reason as the golden floor above -- a differential over a corpus run that
# checked fewer groups than the floor (bead oo-het's "35 of 36 never copied") is not a real
# differential, and must not be reported as "0 divergences".
if len(sm) < floor:
    sys.stderr.write("tier-c-diff: the sm corpus run checked only %d group(s), fewer than the "
                      "floor of %d; a differential over a run that short is vacuous\n" % (len(sm), floor))
    sys.exit(2)
if len(qjs) < floor:
    sys.stderr.write("tier-c-diff: the quickjs corpus run checked only %d group(s), fewer than "
                      "the floor of %d; a differential over a run that short is vacuous\n" % (len(qjs), floor))
    sys.exit(2)

sm_by_name = {r["name"]: r for r in sm}
qjs_by_name = {r["name"]: r for r in qjs}
names = sorted(set(sm_by_name) | set(qjs_by_name))

rows = []
for name in names:
    sr = sm_by_name.get(name)
    qr = qjs_by_name.get(name)
    if sr is None:
        rows.append((name, "MISSING", qr.get("verdict", "?"), ""))
        continue
    if qr is None:
        rows.append((name, sr.get("verdict", "?"), "MISSING", ""))
        continue
    sv, qv = sr.get("verdict"), qr.get("verdict")
    if sv != qv:
        first_err = ""
        for src in (sr, qr):
            errs = src.get("errors") or []
            if errs:
                first_err = errs[0]
                break
        rows.append((name, sv, qv, first_err))

with open(out_path, "w", encoding="utf-8") as fh:
    for name, sv, qv, first_err in rows:
        fh.write("%s\t%s\t%s\t%s\n" % (name, sv, qv, first_err))

print("corpus: %d group(s) compared (sm %d checked, quickjs %d checked), %d divergent"
      % (len(names), len(sm), len(qjs), len(rows)))
PYEOF
CORPUS_CMP_RC=$?
[ "$CORPUS_CMP_RC" -eq 0 ] || die "the corpus comparison refused (rc=$CORPUS_CMP_RC); see the message above"

CORPUS_DIVERGENT=0
CORPUS_ROWS=()
while IFS=$'\t' read -r name sv qv first_err; do
  [ -n "$name" ] || continue
  CORPUS_ROWS+=("$name | $sv | $qv | ${first_err:--}")
  CORPUS_DIVERGENT=$(( CORPUS_DIVERGENT + 1 ))
done < "$CORPUS_ROWS_FILE"

# ---------------------------------------------------------------------------------------------
# 4. THE REPORT.
# ---------------------------------------------------------------------------------------------

SM_CORPUS_COUNT="$("$PY" -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$SM_RESULTS")"
QJS_CORPUS_COUNT="$("$PY" -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$QJS_RESULTS")"
CORPUS_COMPARED=$(( ${#CORPUS_ROWS[@]} ))
# CORPUS_ROWS holds only the DIVERGENT groups (see the python block above), so recover the total
# compared count from the union size, not from the divergent rows.
CORPUS_TOTAL_COMPARED="$("$PY" -c "
import json,sys
sm=json.load(open(sys.argv[1])); qjs=json.load(open(sys.argv[2]))
print(len({r['name'] for r in sm} | {r['name'] for r in qjs}))
" "$SM_RESULTS" "$QJS_RESULTS")"

{
  printf '# Tier C differential report: SpiderMonkey vs QuickJS-ng\n\n'
  printf -- '- sm run:      %s (%s)\n' "$(native "$SM_ROOT")" "$(native "$SM_LOG")"
  printf -- '- quickjs run: %s (%s)\n\n' "$(native "$QJS_ROOT")" "$(native "$QJS_LOG")"
  printf '## Goldens (%d compared, floor %d each side; sm=%d, quickjs=%d dumped)\n\n' \
    "$(printf '%s\n' "$ALL_NAMES" | sed '/^$/d' | wc -l | tr -d ' ')" "$GOLDEN_FLOOR" \
    "$SM_GOLDEN_COUNT" "$QJS_GOLDEN_COUNT"
  if [ "$GOLDEN_DIVERGENT" -eq 0 ]; then
    printf 'NO golden divergences: every scenario byte-for-byte identical between backends.\n\n'
  else
    printf '| scenario | status | first differing line |\n|---|---|---|\n'
    for row in "${GOLDEN_ROWS[@]}"; do
      printf '| %s |\n' "$row"
    done
    printf '\n'
  fi
  printf '## Corpus (%d group(s) compared, floor %d each side; sm=%d, quickjs=%d checked)\n\n' \
    "$CORPUS_TOTAL_COMPARED" "$CORPUS_FLOOR" "$SM_CORPUS_COUNT" "$QJS_CORPUS_COUNT"
  if [ "$CORPUS_DIVERGENT" -eq 0 ]; then
    printf 'NO corpus divergences: every group verdict identical between backends.\n\n'
  else
    printf '| group | sm verdict | quickjs verdict | first differing line |\n|---|---|---|---|\n'
    for row in "${CORPUS_ROWS[@]}"; do
      printf '| %s |\n' "$row"
    done
    printf '\n'
  fi
  TOTAL=$(( GOLDEN_DIVERGENT + CORPUS_DIVERGENT ))
  printf '## Summary\n\n%d total divergence(s): %d golden, %d corpus.\n' \
    "$TOTAL" "$GOLDEN_DIVERGENT" "$CORPUS_DIVERGENT"
} > "$REPORT"

cat "$REPORT"
printf '\ntier-c-diff: report written to %s\n' "$(native "$REPORT")"

TOTAL_DIVERGENT=$(( GOLDEN_DIVERGENT + CORPUS_DIVERGENT ))
if [ "$SM_RC" -ne 0 ] || [ "$QJS_RC" -ne 0 ]; then
  printf 'tier-c-diff: at least one backend run FAILED (sm rc=%d, quickjs rc=%d) -- the report above reflects only what each run actually produced before failing.\n' "$SM_RC" "$QJS_RC" >&2
  exit 1
fi
if [ "$TOTAL_DIVERGENT" -gt 0 ]; then
  printf 'tier-c-diff: %d divergence(s) found between backends; see %s\n' "$TOTAL_DIVERGENT" "$(native "$REPORT")" >&2
  exit 1
fi
printf 'tier-c-diff: GREEN -- no divergence between sm and quickjs across %s golden scenario(s) and %s corpus group(s)\n' \
  "$(printf '%s\n' "$ALL_NAMES" | sed '/^$/d' | wc -l | tr -d ' ')" "$CORPUS_TOTAL_COMPARED"
