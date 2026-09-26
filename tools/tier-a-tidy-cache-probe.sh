#!/usr/bin/env bash
#
# Probe the clang-tidy result cache of tools/tier-a.sh step 2 (bead oo-ej77).
#
#     bash tools/tier-a-tidy-cache-probe.sh        (from an MSYS2 UCRT64 shell: it runs clang-tidy)
#
# The cache memoises ONLY the clang-tidy invocation, keyed on the preprocessed TU; the baseline
# gate still judges whatever output comes back. This proves the three things that make that safe:
#
#   (a) a second run on the same file is a hit ("tidy: cached") and replays byte-identical
#       findings with the same exit status as the first (and as an uncached run);
#   (b) editing a header the TU includes forces a miss;
#   (c) a planted NEW finding still fails the real tidy_gate on the miss that first sees it AND
#       on the hit that replays it.
#
# Nothing is re-implemented: it sources tools/tier-a.sh with OOLITE_TIER_A_SOURCE_ONLY=1 and calls
# ITS tidy_cached and tidy_gate (the tools/tier-a-tidy-probe.sh pattern). The fixture -- a tiny git
# repo with a .clang-tidy, a .cpp and the header it includes -- and the cache directory both live
# in a per-run `mktemp -d` with an EXIT trap, so concurrent workers and the shared fleet cache are
# never touched.
set -u

cd "$(dirname "$0")/.." || exit 1

OOLITE_TIER_A_SOURCE_ONLY=1 . tools/tier-a.sh
set +e   # the sourced file sets -e; the probe must survive its own failing cases

pass=0
failn=0
ok()  { pass=$((pass+1));   printf 'ok   %s\n' "$*"; }
bad() { failn=$((failn+1)); printf 'FAIL %s\n' "$*"; }
check() { # check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then ok "$1 ($3)"; else bad "$1: want=$2 got=$3"; fi
}

for f in tidy_cached tidy_gate; do
	command -v "$f" >/dev/null 2>&1 \
		|| { printf 'FAIL tools/tier-a.sh did not define %s when sourced\n' "$f"; exit 1; }
done
for c in clang clang-tidy python git cygpath; do
	command -v "$c" >/dev/null 2>&1 || { printf 'FAIL missing %s on PATH (run from MSYS2 UCRT64)\n' "$c"; exit 1; }
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/tier-a-tidy-cache-probe.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT
export OOLITE_TIER_A_TIDY_CACHE_DIR="$TMP/cache"
unset OOLITE_TIER_A_NO_TIDY_CACHE

REPO="$TMP/repo"
mkdir -p "$REPO/src" "$REPO/build"
cat >"$REPO/.clang-tidy" <<'EOF'
Checks: '-*,misc-unused-parameters'
EOF
cat >"$REPO/src/fixture.h" <<'EOF'
#define FIXTURE_VALUE 1
EOF
cat >"$REPO/src/fixture.cpp" <<'EOF'
#include "fixture.h"

int used(int x)
{
	return x + FIXTURE_VALUE;
}

int preexisting(int unusedOld)
{
	return FIXTURE_VALUE;
}
EOF
git -C "$REPO" init -q && git -C "$REPO" add -A \
	&& git -C "$REPO" -c user.name=probe -c user.email=probe@invalid commit -qm base \
	|| { printf 'FAIL could not create the fixture repo\n'; exit 1; }
BASE="$(git -C "$REPO" rev-parse HEAD)"
SRC="$REPO/src/fixture.cpp"
SRC_NATIVE="$(cygpath -m "$SRC")"
ARGS=(-x c++ -std=c++17 -I../src)

# run <name>: tidy_cached into $TMP/<name>.out; records its stdout (the hit/store notes) and rc.
run() {
	local name="$1" rc=0
	tidy_cached "$REPO" "$REPO/build" "$SRC_NATIVE" "$TMP/$name.out" "${ARGS[@]}" >"$TMP/$name.log" 2>&1 || rc=$?
	printf '%s' "$rc" >"$TMP/$name.rc"
}
hit() { grep -q 'tidy: cached' "$TMP/$1.log" && echo hit || echo miss; }
gate() { local rc=0; tidy_gate "$REPO" "$BASE" "$SRC" "src/fixture.cpp" "$TMP/$1.out" >/dev/null 2>&1 || rc=$?; echo "$rc"; }

# --- (a) same file twice: miss then hit, identical findings --------------------------------
run a1
run a2
check "(a) first run is a miss" miss "$(hit a1)"
check "(a) first run stores an entry" 1 "$(find "$TMP/cache" -type f ! -name '.tmp.*' | wc -l | tr -d ' ')"
check "(a) second run is a hit" hit "$(hit a2)"
check "(a) same exit status on the hit" "$(cat "$TMP/a1.rc")" "$(cat "$TMP/a2.rc")"
if cmp -s "$TMP/a1.out" "$TMP/a2.out"; then ok "(a) replayed findings are byte-identical"; else bad "(a) replayed findings differ"; diff "$TMP/a1.out" "$TMP/a2.out"; fi
grep -q 'unusedOld' "$TMP/a2.out" && ok "(a) the replay carries the pre-existing finding" || bad "(a) the replay lost the finding"
OOLITE_TIER_A_NO_TIDY_CACHE=1 run nocache
check "(a) OOLITE_TIER_A_NO_TIDY_CACHE=1 does not read the cache" miss "$(hit nocache)"
if cmp -s "$TMP/a1.out" "$TMP/nocache.out"; then ok "(a) cached output equals an uncached run"; else bad "(a) cached output differs from an uncached run"; fi
check "(a) the pre-existing finding passes the gate on the hit" 0 "$(gate a2)"

# --- (b) a header edit forces a miss ------------------------------------------------------
printf '#define FIXTURE_VALUE 2\n' >"$REPO/src/fixture.h"
run b1
check "(b) editing the included header is a miss" miss "$(hit b1)"
run b2
check "(b) ... and the new content then hits" hit "$(hit b2)"

# --- (c) a planted new finding fails on the miss and on the hit ---------------------------
cat >>"$SRC" <<'EOF'

int planted(int unusedNew)
{
	return 0;
}
EOF
run c1
run c2
check "(c) the planted finding is first seen on a miss" miss "$(hit c1)"
check "(c) the planted finding fails the gate on the miss" 1 "$(gate c1)"
check "(c) the second run is a hit" hit "$(hit c2)"
check "(c) the planted finding still fails the gate on the hit" 1 "$(gate c2)"
grep -q 'unusedNew' "$TMP/c2.out" && ok "(c) the hit replays the planted finding" || bad "(c) the hit lost the planted finding"

# --- shared across checkouts: another root hits and names ITS OWN files ---------------------
cp -r "$REPO" "$TMP/other"
OTHER_NATIVE="$(cygpath -m "$TMP/other")"
rc=0
tidy_cached "$TMP/other" "$TMP/other/build" "$OTHER_NATIVE/src/fixture.cpp" "$TMP/d1.out" "${ARGS[@]}" >"$TMP/d1.log" 2>&1 || rc=$?
check "(d) the same TU in another checkout is a hit" hit "$(hit d1)"
check "(d) ... with the same exit status" "$(cat "$TMP/c2.rc")" "$rc"
grep -qiF "$OTHER_NATIVE/src/fixture.cpp" "$TMP/d1.out" && ok "(d) the replay names the other checkout's file" || bad "(d) the replay does not name the other checkout's file"
grep -qiF "$SRC_NATIVE" "$TMP/d1.out" && bad "(d) the replay still names the first checkout" || ok "(d) no path from the first checkout leaks"

# --- the switch: OOLITE_TIER_A_NO_TIDY_CACHE=1 neither reads nor writes --------------------
before="$(find "$TMP/cache" -type f | wc -l | tr -d ' ')"
printf '\nint another(int unusedMore) { return 0; }\n' >>"$SRC"
OOLITE_TIER_A_NO_TIDY_CACHE=1 run e1
check "(e) a disabled run writes no entry" "$before" "$(find "$TMP/cache" -type f | wc -l | tr -d ' ')"

printf '%s passed, %s failed\n' "$pass" "$failn"
[ "$failn" -eq 0 ]
