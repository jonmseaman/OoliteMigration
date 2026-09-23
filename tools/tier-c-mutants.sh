#!/usr/bin/env bash
# tools/tier-c-mutants.sh -- PROVE THE GATE CAN FAIL (bead oo-j4u).
#
# A gate nobody has seen go red is a gate nobody has tested. For each property Tier C defends this
# script builds a MUTANT that breaks exactly that property, runs the relevant line, shows it RED
# naming the STAGE and the reason, then restores and shows GREEN.
#
# TWO MUTANTS PER PROPERTY, because bead oo-jor shipped a gate whose DATA was protected but whose
# CHECKER was not, and bead oo-9w5's count floor passed while the spec lost its hardest clause:
#   * a DATA mutant corrupts the artefact the check reads;
#   * a CHECKER mutant weakens the check itself.
# A surviving mutant means a blind gate, an EQUIVALENT mutant, or a redundant defence -- and this
# script says which.
#
# Every mutation is applied to a THROWAWAY COPY under $RUN/, never to the tree, and every original
# is restored in a trap. Nothing under goldens/ is touched at all.
#
#     tools/tier-c-mutants.sh            # run them all
#     tools/tier-c-mutants.sh 3          # run one by number

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
cd "$REPO" || exit 2
[ -d /ucrt64/bin ] && export PATH="/ucrt64/bin:$PATH"
PY=python3; command -v $PY >/dev/null 2>&1 || PY=python

RUN="$(mktemp -d "${TMPDIR:-/tmp}/tier-c-mutants-XXXXXX")"
PASS=0; FAIL=0; ONLY="${1:-}"
restore_all() { :; }
trap 'restore_all; rm -rf "$RUN"' EXIT

hr() { printf '\n%s\n' "------------------------------------------------------------------------"; }

# expect_red <n> <name> <what-it-protects> <expected-substring> <command...>
# The RED assertion is on the STAGE NAME and REASON, never merely on rc!=0: bead oo-1xz lost an
# acceptance because a red-proof line got the right exit code from the WRONG stage.
expect_red() {
  local n="$1" name="$2" protects="$3" want="$4"; shift 4
  [ -n "$ONLY" ] && [ "$ONLY" != "$n" ] && return 0
  hr; printf 'MUTANT %s: %s\n  protects: %s\n  expects RED matching: %s\n\n' "$n" "$name" "$protects" "$want"
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  printf '%s\n' "$out" | sed 's/^/  | /' | head -14
  printf '  -> rc=%s\n' "$rc"
  if [ "$rc" -eq 0 ]; then
    printf '  RESULT: SURVIVED -- the gate stayed GREEN with the mutation applied. BLIND GATE.\n'
    FAIL=$(( FAIL + 1 )); return 1
  fi
  if printf '%s' "$out" | grep -qF "$want"; then
    printf '  RESULT: KILLED (rc=%s, and the message names the right stage/reason)\n' "$rc"
    PASS=$(( PASS + 1 )); return 0
  fi
  printf '  RESULT: rc=%s but the message did NOT match %s -- right exit code, possibly WRONG stage.\n' "$rc" "$want"
  FAIL=$(( FAIL + 1 )); return 1
}

expect_green() {
  local label="$1"; shift
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then printf '  RESTORED: %s is GREEN again (rc=0)\n' "$label"
  else printf '  RESTORED BUT STILL RED (rc=%s): %s\n' "$rc" "$label"; printf '%s\n' "$out" | tail -5 | sed 's/^/    | /'; FAIL=$(( FAIL + 1 )); fi
}

# ================================================================================================
# STAGE jsapi -- the snapshot must not drift from engine source, and must agree with the runtime.
# ================================================================================================

# 1. DATA: the committed snapshot drifts from the engine source.
#    This is bead oo-4z6's "tier2 is STALE ... committed 63990 bytes, fresh 11983" applied to the
#    JS API: a snapshot nobody regenerates is documentation, not a gate.
SNAP="oxp-contract/js-api-source.json"
if [ -z "$ONLY" ] || [ "$ONLY" = 1 ]; then
  cp "$SNAP" "$RUN/snap.orig"
  restore_all() { cp -f "$RUN/snap.orig" "$SNAP" 2>/dev/null || true; }
  $PY - "$SNAP" <<'PYEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
# Flip Ship.speed to readwrite: the single most load-bearing fact in the file (bead oo-jou1).
d["classes"]["Ship"]["properties"]["speed"]["access"] = "readwrite"
json.dump(d, open(p, "w"), indent=2, sort_keys=True)
PYEOF
  expect_red 1 "jsapi DATA: committed snapshot drifted from source (Ship.speed flipped to readwrite)" \
    "the committed JS API snapshot is regenerated and byte-compared, so it cannot silently rot" \
    "FAIL (stage jsapi)" bash tools/tier-c.sh --only jsapi
  cp -f "$RUN/snap.orig" "$SNAP"; restore_all() { :; }
  expect_green "tier-c --only jsapi" bash tools/tier-c.sh --only jsapi
fi

# 2. CHECKER: the drift check itself is weakened to always agree.
#    The oo-jor lesson: protecting the data is not protecting the checker. If someone replaces the
#    byte-comparison with a no-op, mutant 1 would stop being caught -- so the SELFTEST must notice
#    the guard is gone.
if [ -z "$ONLY" ] || [ "$ONLY" = 2 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig"
  restore_all() { cp -f "$RUN/tier-c.orig" tools/tier-c.sh 2>/dev/null || true; }
  # Remove the assertion that the check really reported a byte-identical scrape.
  $PY - <<'PYEOF'
import pathlib
p = pathlib.Path("tools/tier-c.sh"); t = p.read_text()
t = t.replace("byte-identical to a fresh scrape", "SOMETHING THAT NEVER MATCHES")
p.write_text(t)
PYEOF
  expect_red 2 "jsapi CHECKER: the byte-comparison assertion deleted from tier-c.sh" \
    "the selftest pins the guard itself, not just the data it guards" \
    "GUARD MISSING [jsapi byte-comparison]" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# 3. DATA: the source/runtime reconciliation finds a NEW mutability disagreement.
#    This is the discrepancy class bead oo-jou1 was filed for, and the one an OXP author is
#    actively misled by.
if [ -z "$ONLY" ] || [ "$ONLY" = 3 ]; then
  cp "$SNAP" "$RUN/snap.orig3"
  restore_all() { cp -f "$RUN/snap.orig3" "$SNAP" 2>/dev/null || true; }
  $PY - "$SNAP" <<'PYEOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
# Ship.subEntityCapacity is READONLY in source and the runtime agrees. Flip only the source copy,
# leaving the file otherwise well-formed, so ONLY the reconciliation can catch it.
for name in ("subEntityCapacity", "maxThrust", "heatInsulation"):
    pr = d["classes"]["Ship"]["properties"].get(name)
    if pr and pr.get("access") == "readonly":
        pr["access"] = "readwrite"; break
json.dump(d, open(p, "w"), indent=2, sort_keys=True)
PYEOF
  expect_red 3 "jsapi DATA: a property's declared mutability disagrees with the live interpreter" \
    "the two snapshots cross-check each other; neither can catch this alone" \
    "FAIL (stage jsapi)" bash tools/tier-c.sh --only jsapi
  cp -f "$RUN/snap.orig3" "$SNAP"; restore_all() { :; }
  expect_green "tier-c --only jsapi" bash tools/tier-c.sh --only jsapi
fi

# 4. CHECKER: the reconciliation's anti-vacuity floor removed, and its input emptied.
#    A cross-check that compares nothing agrees perfectly. This proves the REFUSAL path works:
#    rc=2 must not read as success.
if [ -z "$ONLY" ] || [ "$ONLY" = 4 ]; then
  cp "$SNAP" "$RUN/snap.orig4"
  restore_all() { cp -f "$RUN/snap.orig4" "$SNAP" 2>/dev/null || true; }
  $PY -c "
import json,sys
json.dump({'schema':'oolite-js-api-source/1','classes':{},'summary':{'class_count':0}}, open('$SNAP','w'))
"
  expect_red 4 "jsapi CHECKER: the snapshot emptied so the reconciliation has nothing to compare" \
    "a refusal (rc=2) is never a pass; an empty snapshot must not agree perfectly" \
    "FAIL (stage jsapi)" bash tools/tier-c.sh --only jsapi
  cp -f "$RUN/snap.orig4" "$SNAP"; restore_all() { :; }
  expect_green "tier-c --only jsapi" bash tools/tier-c.sh --only jsapi
fi

# ================================================================================================
# STAGE asan -- the sanitizer must be live, attributable, and narrowly suppressed.
# ================================================================================================

# 5. DATA: the ASan suppressions file is widened to cover the module under test.
#    This is the single edit that would turn the whole ASan stage into an expensive no-op.
if [ -z "$ONLY" ] || [ "$ONLY" = 5 ]; then
  cp tools/asan-suppressions.txt "$RUN/supp.orig"
  restore_all() { cp -f "$RUN/supp.orig" tools/asan-suppressions.txt 2>/dev/null || true; }
  printf 'interceptor_via_lib:oolite.exe\n' >> tools/asan-suppressions.txt
  expect_red 5 "asan DATA: a suppression added that matches oolite.exe itself" \
    "suppressions must name third-party modules only; one matching our own module hides every defect" \
    "mentions oolite" $PY tools/tier_c_selftest.py
  cp -f "$RUN/supp.orig" tools/asan-suppressions.txt; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# 6. CHECKER: the attribution verdict removed from tier-c.sh.
#    Without it the stage would report third-party findings and pass regardless of ours.
if [ -z "$ONLY" ] || [ "$ONLY" = 6 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig6"
  restore_all() { cp -f "$RUN/tier-c.orig6" tools/tier-c.sh 2>/dev/null || true; }
  $PY - <<'PYEOF'
import pathlib
p = pathlib.Path("tools/tier-c.sh"); t = p.read_text()
t = t.replace("attributable to oolite.exe", "reports seen")
p.write_text(t)
PYEOF
  expect_red 6 "asan CHECKER: the oolite.exe attribution verdict deleted" \
    "the pass condition is zero OUR-code reports, not zero reports" \
    "GUARD MISSING [asan attribution verdict]" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig6" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# 7. CHECKER: the symbolisation precondition removed.
#    Without symbolisation every frame is a bare address, so the attribution check in mutant 6
#    would silently report "0 ours" for a run full of engine defects. This is the mutant that
#    proves the two ASan guards are not redundant.
if [ -z "$ONLY" ] || [ "$ONLY" = 7 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig7"
  restore_all() { cp -f "$RUN/tier-c.orig7" tools/tier-c.sh 2>/dev/null || true; }
  $PY - <<'PYEOF'
import pathlib
p = pathlib.Path("tools/tier-c.sh"); t = p.read_text()
t = t.replace("could not resolve", "resolved fine")
p.write_text(t)
PYEOF
  expect_red 7 "asan CHECKER: the symbolisation precondition deleted" \
    "a stage that cannot attribute a frame to a module cannot tell our defect from a DLL's quirk" \
    "GUARD MISSING [asan symbolisation precondition]" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig7" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# ================================================================================================
# STAGE corpus / goldens / gui -- floors and composition.
# ================================================================================================

# 8. CHECKER: the full-Tier-1 floor lowered to a value tier-b's 3-group subset would satisfy.
#    The tempting "fix" when the gate goes red, and the one that silently narrows it to Tier B.
if [ -z "$ONLY" ] || [ "$ONLY" = 8 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig8"
  restore_all() { cp -f "$RUN/tier-c.orig8" tools/tier-c.sh 2>/dev/null || true; }
  sed -i 's/CORPUS_FLOOR:-36/CORPUS_FLOOR:-3/' tools/tier-c.sh
  expect_red 8 "corpus CHECKER: the 36-group floor lowered to 3" \
    "Tier C's corpus stage is the FULL Tier 1; a floor of 3 makes it Tier B's subset" \
    "below the committed minimum" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig8" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# 9. DATA: a whole stage deleted from the composition.
#    "It was slow so I removed it" is how a merge gate quietly becomes a commit gate.
if [ -z "$ONLY" ] || [ "$ONLY" = 9 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig9"
  restore_all() { cp -f "$RUN/tier-c.orig9" tools/tier-c.sh 2>/dev/null || true; }
  sed -i '/^asan\\t135\\t/d' tools/tier-c.sh
  expect_red 9 "composition DATA: the asan stage deleted from the STAGES table" \
    "a stage that is slow is not a stage that is optional" \
    "COMPOSITION" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig9" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# 10. CHECKER: the GUI stage's skip-is-a-failure assertion removed.
#     OO_GUI_REQUIRE=1 exists so "G1 passed" and "G1 never ran" cannot look alike; without the
#     zero-skipped assertion they can again.
if [ -z "$ONLY" ] || [ "$ONLY" = 10 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig10"
  restore_all() { cp -f "$RUN/tier-c.orig10" tools/tier-c.sh 2>/dev/null || true; }
  $PY - <<'PYEOF'
import pathlib
p = pathlib.Path("tools/tier-c.sh"); t = p.read_text()
t = t.replace("a skip is a failure", "skips are fine")
p.write_text(t)
PYEOF
  expect_red 10 "gui CHECKER: the skip-is-a-failure assertion deleted" \
    "a GUI tier that skipped is not a GUI tier that passed" \
    "GUARD MISSING [gui skip-is-failure]" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig10" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

# 11. DATA: the tier's printed plan silently loses a stage.
#     This mutant reproduces a REAL BUG found while building this tier: `while read` drops a final
#     line with no trailing newline, so the STAGES table listed 6 stages while --list and --dry-run
#     emitted 5. Parsing the variable found nothing wrong; only RUNNING the tier did.
if [ -z "$ONLY" ] || [ "$ONLY" = 11 ]; then
  cp tools/tier-c.sh "$RUN/tier-c.orig11"
  restore_all() { cp -f "$RUN/tier-c.orig11" tools/tier-c.sh 2>/dev/null || true; }
  $PY - <<'PYEOF'
import pathlib
p = pathlib.Path("tools/tier-c.sh"); t = p.read_text()
# Reintroduce the exact defect: drop the trailing newline before the read loops.
t = t.replace("""all_stage_names() { printf '%b\\n' "$STAGES\"""",
              """all_stage_names() { printf '%b' "$STAGES\"""")
p.write_text(t)
PYEOF
  expect_red 11 "composition DATA: the last stage silently dropped from the printed plan" \
    "a gate whose printed plan omits a stage also RUNS without it (a real bug, found this way)" \
    "RUNTIME" $PY tools/tier_c_selftest.py
  cp -f "$RUN/tier-c.orig11" tools/tier-c.sh; restore_all() { :; }
  expect_green "tier_c_selftest.py" $PY tools/tier_c_selftest.py
fi

hr; printf "DEBUG PASS=%s FAIL=%s
" "$PASS" "$FAIL"
printf '\ntier-c-mutants: %d killed, %d survived/misattributed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
