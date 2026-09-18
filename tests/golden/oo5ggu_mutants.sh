#!/usr/bin/env bash
# oo-5ggu mutation harness. For each substantive acceptance line, break EXACTLY what it protects,
# show it RED naming the failure, restore, and show it GREEN again.
#
# BASELINE EVERY LINE FIRST (fleet learning oo-4vdc): a line that is already red at baseline
# registers as a successful kill for every mutant, which manufactures evidence that the gate
# discriminates when it does not. This aborts if any baselined line is not rc=0.
#
# Everything is restored by a trap, and every scratch file lives under this worktree's own temp
# dir - never the shared repo root (oo-4vdc again).
set -uo pipefail
export PATH=/ucrt64/bin:$PATH

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO"
PROV=goldens/windows-x64/001/provenance.json
FLAGS=tests/golden/check_flags_from_source.sh
TMP="${LOCALAPPDATA:-/tmp}/Temp/oo5ggu-mutants-$$"
mkdir -p "$TMP"

# RESTORE FROM A SAVED COPY, NOT `git checkout --`. Measured the hard way: the first run of this
# harness used `git checkout -- $PROV`, which restores the file as of HEAD - and while the
# re-bless is still uncommitted that is the OLD, verified=false provenance. Every mutant after
# the first then ran against a baseline that was already red in the direction being tested, so
# B/L3 and C/L3 reported rc=0 and looked like the gate failing to discriminate when in fact the
# harness had destroyed the thing under test. A worktree copy is what "restore" has to mean.
cp "$PROV" "$TMP/provenance.orig.json"

restore() {
  [ -f "$TMP/provenance.orig.json" ] && cp "$TMP/provenance.orig.json" "$PROV"
  rm -rf "$TMP"
}
trap restore EXIT
unmutate() { cp "$TMP/provenance.orig.json" "$PROV"; }

run() { # run <label> <expected-rc-word> <cmd...>
  local label="$1"; shift
  local want="$1"; shift
  echo "----- $label"
  "$@" >"$TMP/out" 2>"$TMP/err"
  local rc=$?
  echo "rc=$rc  ($want expected)"
  sed 's/^/    /' "$TMP/err" | head -12
  sed 's/^/    /' "$TMP/out" | head -6
  echo
  return $rc
}

echo "=========================================================="
echo "BASELINE: every acceptance line that this harness mutates"
echo "=========================================================="
run "L1 baseline check_provenance_verified" GREEN \
    python3 tests/golden/check_provenance_verified.py 001 || { echo "ABORT: L1 red at baseline"; exit 1; }
run "L2 baseline check_flags_from_source" GREEN \
    bash "$FLAGS" || { echo "ABORT: L2 red at baseline"; exit 1; }
run "L3 baseline pytest test_golden_storage" GREEN \
    python3 -m pytest tests/golden/test_golden_storage.py -q || { echo "ABORT: L3 red at baseline"; exit 1; }

echo "=========================================================="
echo "MUTANT A (line 1+3): provenance claims verified=true with"
echo "a plausible hand-written detail instead of the checker's"
echo "own 'compliant' verdict - the exact hand-edit the bead"
echo "forbids. Both gates must refuse it."
echo "=========================================================="
python3 - "$PROV" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["build_flags"]["detail"] = "looks fine to me, we definitely built with -ffp-contract=off"
json.dump(d, open(p, "w", encoding="utf-8", newline="\n"), indent=2, sort_keys=True)
PY
run "A/L1 RED" RED python3 tests/golden/check_provenance_verified.py 001
run "A/L3 RED" RED python3 -m pytest tests/golden/test_golden_storage.py -q \
    -k provenance_records_OBSERVED
unmutate
run "A/L1 GREEN restored" GREEN python3 tests/golden/check_provenance_verified.py 001

echo "=========================================================="
echo "MUTANT B (line 1+3): verified=true blessed from a build"
echo "database of only 3 translation units - the vacuous form of"
echo "'every TU carries the flag'."
echo "=========================================================="
python3 - "$PROV" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["build_flags"]["translation_units"] = 3
d["build_flags"]["effective_optimization_levels"] = {"-O2": 3}
json.dump(d, open(p, "w", encoding="utf-8", newline="\n"), indent=2, sort_keys=True)
PY
run "B/L1 RED" RED python3 tests/golden/check_provenance_verified.py 001
run "B/L3 RED" RED python3 -m pytest tests/golden/test_golden_storage.py -q \
    -k provenance_records_OBSERVED
unmutate

echo "=========================================================="
echo "MUTANT C (line 1): the meson -O0-after-O2 trap, recorded."
echo "verified=true and detail=compliant, but the EFFECTIVE level"
echo "observed was -O0 - i.e. the build oo-ss8 caught."
echo "=========================================================="
python3 - "$PROV" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["build_flags"]["effective_optimization_levels"] = {"-O0": 243}
json.dump(d, open(p, "w", encoding="utf-8", newline="\n"), indent=2, sort_keys=True)
PY
run "C/L1 RED" RED python3 tests/golden/check_provenance_verified.py 001
run "C/L3 RED" RED python3 -m pytest tests/golden/test_golden_storage.py -q \
    -k provenance_records_OBSERVED
unmutate
run "C/L3 GREEN restored" GREEN python3 -m pytest tests/golden/test_golden_storage.py -q

echo "=========================================================="
echo "MUTANT D (line 2): a build database missing the flag."
echo "check_build_flags is pointed at the SHARED build dir, which"
echo "genuinely predates the pin - a real non-compliant database,"
echo "not a synthetic one."
echo "=========================================================="
run "D/L2 RED (shared pre-flag build dir)" RED \
    python3 tests/golden/check_build_flags.py \
      --build-dir C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test
run "D/L2 GREEN (configured from source)" GREEN bash "$FLAGS"

echo "=========================================================="
echo "MUTANT E (line 2): -Ddebug=false removed, so meson appends"
echo "-O0 AFTER -O2 and the build really compiles at -O0 while"
echo "'-O2' is still on every command line."
echo "=========================================================="
E="$TMP/nodebugfalse"
MINGW_PREFIX=/ucrt64 MSYSTEM=UCRT64 bash -c \
  'meson setup "$1" "$2" >/dev/null 2>&1' _ "$(cygpath -m "$E")" "$(cygpath -m "$REPO/upstream/oolite")"
run "E/L2 RED (no -Ddebug=false)" RED \
    python3 tests/golden/check_build_flags.py --build-dir "$(cygpath -m "$E")"

echo "=========================================================="
echo "MUTANT F (line 4): a THROWAWAY copy of the golden perturbed"
echo "by exactly one quantised unit. goldens/ is never touched -"
echo "the copy is diffed in the temp dir."
echo "=========================================================="
G=goldens/windows-x64/001
cp -r "$G" "$TMP/g-clean"
cp -r "$G" "$TMP/g-mutant"
python3 - "$TMP/g-mutant/state.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
e = d["entities"][0]
before = e["position"][0]
e["position"][0] = round(before + 0.001, 3)
assert e["position"][0] != before
open(p, "w", encoding="utf-8", newline="\n").write(
    json.dumps(d, sort_keys=True, separators=(",", ":")) + "\n")
print("perturbed entities[%s].position[0] %r -> %r" % (e["id"], before, e["position"][0]))
PY
run "F/diff RED (1 quantised unit)" RED python3 tests/golden/golden_diff.py \
    "$(cygpath -m "$TMP/g-clean/state.json")" "$(cygpath -m "$TMP/g-mutant/state.json")"
run "F/diff GREEN (clean copy vs real golden)" GREEN python3 tests/golden/golden_diff.py \
    "$(cygpath -m "$REPO/$G/state.json")" "$(cygpath -m "$TMP/g-clean/state.json")"

echo "=========================================================="
echo "MUTANT G (line 4): quantisation coarsened in the throwaway"
echo "copy's provenance. Rounding harder must REFUSE (rc=2), not"
echo "silently pass."
echo "=========================================================="
python3 - "$TMP/g-clean/provenance.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["quant_decimals"] = 0
json.dump(d, open(p, "w", encoding="utf-8", newline="\n"), indent=2, sort_keys=True)
PY
run "G/diff REFUSED rc=2" REFUSED python3 tests/golden/golden_diff.py \
    "$(cygpath -m "$TMP/g-clean/state.json")" "$(cygpath -m "$REPO/$G/state.json")"

echo "=========================================================="
echo "MUTANT H (line 4): self-comparison. A file always equals"
echo "itself, and a hardlink is not a second run."
echo "=========================================================="
ln "$TMP/g-clean/state.json" "$TMP/linked.json" 2>/dev/null
run "H/same path REFUSED rc=2" REFUSED python3 tests/golden/golden_diff.py \
    "$(cygpath -m "$REPO/$G/state.json")" "$(cygpath -m "$REPO/$G/state.json")"
run "H/hardlink REFUSED rc=2" REFUSED python3 tests/golden/golden_diff.py \
    "$(cygpath -m "$TMP/g-clean/state.json")" "$(cygpath -m "$TMP/linked.json")"

echo "=========================================================="
echo "FINAL: everything restored, all baselined lines GREEN"
echo "=========================================================="
unmutate
run "L1 final GREEN" GREEN python3 tests/golden/check_provenance_verified.py 001
run "L2 final GREEN" GREEN bash "$FLAGS"
run "L3 final GREEN" GREEN python3 -m pytest tests/golden/test_golden_storage.py -q
echo "git status --porcelain goldens/:"; git status --porcelain goldens/; echo "(empty above = restored)"
