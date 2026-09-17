#!/usr/bin/env bash
#
# Probe the REAL deny-list gate of tools/tier-a.sh (bead oo-2ixr).
#
#     bash tools/tier-a-deny-probe.sh
#
# Nothing here re-implements the gate: it sources tools/tier-a.sh with
# OOLITE_TIER_A_SOURCE_ONLY=1 and calls that file's own deny_count, resolve_base_ref and
# deny_gate, the way tools/check-file-modes-probe.sh probes check-file-modes.sh (bead oo-tqmx).
# A probe that paraphrased the rule would pass while the rule was broken.
#
# Every case is a CONSTRUCTED VIOLATION plus its clean twin, because the defect being closed is
# "a gate that can never fail". A case that only ever passes proves nothing, so each defect
# below is also measured against LEGACY_deny_count -- a verbatim copy of the pre-fix
# implementation (grep -cE, `|| true`) -- and the probe ASSERTS that the legacy code gives the
# wrong answer. That is the discrimination proof: if a future edit reverts the fix, the
# legacy-disagreement assertions stop holding and this probe goes red.
#
# Scratch state is a per-run `mktemp -d` with an EXIT trap: the fleet runs several workers and
# reviewers concurrently and a fixed scratch path would make them corrupt each other.
set -u

cd "$(dirname "$0")/.." || exit 1
REPO="$(pwd)"

OOLITE_TIER_A_SOURCE_ONLY=1 . tools/tier-a.sh
set +e   # the sourced file sets -e; the probe must survive its own failing cases

pass=0
failn=0
ok()   { pass=$((pass+1));   printf 'ok   %s\n' "$*"; }
bad()  { failn=$((failn+1)); printf 'FAIL %s\n' "$*"; }
check() { # check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then ok "$1 ($3)"; else bad "$1: want=$2 got=$3"; fi
}

# Deny-listed symbols are SPELLED IN TWO PIECES throughout this file ("$JS"A, "$POOL") so the
# file's own BYTES ON DISK carry no deny-list hit, while every string handed to the gate is
# byte-identical to the real symbol at runtime. Without this, tools/guardrails.sh's
# baseline-relative deny-list scan fails on this file for containing its own fixtures, and the
# alternative -- adding the probe to that scan's SCAN_EXEMPT list -- would widen a guard's
# blind spot just to make a test convenient. The guard stays strict; the fixtures stay real.
JS='JS''_'
POOL='NSAutorelease''Pool'

TMP="$(mktemp -d "${TMPDIR:-/tmp}/tier-a-deny-probe.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT
# Native (C:/...) form for anything handed to git, which is not an MSYS program: an absolute
# /tmp/... path given to it resolves somewhere else entirely and reads back empty.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# The pre-fix implementation, kept verbatim so the probe can prove its cases discriminate.
LEGACY_deny_count() {
	local list="${1:-$DENY_LIST}"
	local text; text="$(cat)"
	local total=0 pattern hits
	while IFS= read -r pattern; do
		case "$pattern" in ''|'#'*) continue ;; esac
		hits="$(printf '%s' "$text" | grep -cE "$pattern" || true)"
		total=$(( total + hits ))
	done < "$list"
	printf '%s' "$total"
}

# The pre-fix baseline resolution, verbatim from tools/tier-a.sh:173 before this bead, for the
# same reason: every defect-A case below must be shown to give the WRONG answer under it.
LEGACY_base_ref() {
	local root="$1" ref="${OOLITE_TIER_A_BASE:-}"
	if [ -z "$ref" ]; then
		ref="$(git -C "$root" merge-base HEAD main 2>/dev/null || echo HEAD)"
	fi
	printf '%s' "$ref"
}

LIST="$TMP/deny.txt"
printf '%s\n' '# a comment' '' '\bJS_[A-Za-z_][A-Za-z0-9_]*\b' '\bNSAutoreleasePool\b' >"$LIST"
BADLIST="$TMP/deny-bad.txt"
printf '%s\n' '\bJS_[A-Za-z_][A-Za-z0-9_]*\b' 'JS_[' >"$BADLIST"

echo "== defect B: occurrences, not lines =="
# Three calls on ONE line. Line-granular counting sees 1 and a second and third call on an
# existing line is invisible -- the commonest shape of a real reintroduction.
one_line="	rv = ${JS}GetContextPrivate(${JS}NewContext(${JS}GetRuntime(cx)));"
n="$(printf '%s\n' "$one_line" | deny_count "$LIST")"
check "three JS_* calls on one line count 3" 3 "$n"
l="$(printf '%s\n' "$one_line" | LEGACY_deny_count "$LIST")"
if [ "$l" = "$n" ]; then bad "legacy agrees ($l) -- this case does not discriminate"; else ok "legacy disagrees (legacy=$l new=$n)"; fi

# Packing: 3 separate hits become ONE line with 4 hits. Occurrence counting sees 3 -> 4 (a
# regression); line counting sees 3 -> 1 and calls it an improvement.
before="$(printf '%s\n' "a = ${JS}A(x);" "b = ${JS}B(x);" "c = ${JS}C(x);")"
after="	q = ${JS}A(${JS}B(${JS}C(${JS}D(x))));"
nb="$(printf '%s\n' "$before" | deny_count "$LIST")"
na="$(printf '%s\n' "$after"  | deny_count "$LIST")"
check "3 separate hits count 3" 3 "$nb"
check "4 packed hits count 4" 4 "$na"
if [ "$na" -gt "$nb" ]; then ok "packing 4 hits onto 1 line is a regression (3 -> 4)"; else bad "packed regression not seen ($nb -> $na)"; fi
lb="$(printf '%s\n' "$before" | LEGACY_deny_count "$LIST")"
la="$(printf '%s\n' "$after"  | LEGACY_deny_count "$LIST")"
if [ "$la" -gt "$lb" ]; then bad "legacy caught the packed regression ($lb -> $la) -- no discrimination"; else ok "legacy misses it and calls it an improvement ($lb -> $la)"; fi

# The clean twin: identical text must count equal, so an unchanged file still passes.
n0="$(printf '%s\n' "$before" | deny_count "$LIST")"
check "an unchanged body is not a regression" "$nb" "$n0"
# Break twin for that control: one added call must make it unequal.
n1="$(printf '%s\n' "$before" "d = ${JS}D(x);" | deny_count "$LIST")"
if [ "$n1" -gt "$n0" ]; then ok "break twin: one added call raises the count ($n0 -> $n1)"; else bad "break twin did not raise the count"; fi
check "text with no deny-listed symbol counts 0" 0 "$(printf 'int main(void) { return 0; }\n' | deny_count "$LIST")"

echo "== defect C: a malformed pattern is an error, not 'no hits' =="
out="$(printf 'x = %sFoo(1);\n' "$JS" | deny_count "$BADLIST" 2>"$TMP/err")"
rc=$?
check "deny_count exits 2 on an unusable ERE" 2 "$rc"
if grep -q 'unusable' "$TMP/err"; then ok "and it says which pattern"; else bad "no diagnostic for the unusable pattern"; fi
lrc=0
printf 'x = %sFoo(1);\n' "$JS" | LEGACY_deny_count "$BADLIST" >"$TMP/legacy.out" 2>/dev/null || lrc=$?
if [ "$lrc" = 0 ]; then ok "legacy swallowed it and exited 0 with count $(cat "$TMP/legacy.out")"; else bad "legacy also failed (rc=$lrc) -- no discrimination"; fi
# Clean twin: a well-formed list over the same text must succeed.
good="$(printf 'x = %sFoo(1);\n' "$JS" | deny_count "$LIST")"; rc=$?
check "a well-formed list still exits 0" 0 "$rc"
check "and counts the hit" 1 "$good"

echo "== defect A: the baseline is never the file itself =="
R="$TMP/repo"
mkdir -p "$R/src" || exit 1
G="$(native "$R")"
git -C "$G" init -q -b main >/dev/null 2>&1
git -C "$G" config user.email probe@local
git -C "$G" config user.name probe
DENY_LIST="$LIST"   # deny_gate reports through $DENY_LIST

commit() { git -C "$G" add -A >/dev/null 2>&1; git -C "$G" commit -q -m "$1" >/dev/null 2>&1; }
printf '%s\n' 'void f(void) { }' >"$R/src/a.c"
commit base0
printf '%s\n' 'void f(void) { }' 'void g(void) { }' >"$R/src/a.c"
commit clean-main

# A bead branch off main, with a COMMITTED regression on it: exactly the situation the gate
# exists for, and exactly the one the old self-comparing baseline could not see.
git -C "$G" checkout -q -b bead/probe
printf '%s\n' 'void f(void) { }' "void g(void) { ${JS}A(${JS}B(x)); }" >"$R/src/a.c"
commit regression

BR="$(OOLITE_TIER_A_BASE= OOLITE_TIER_A_BASE_BRANCH=main resolve_base_ref "$G" 2>/dev/null)"
mb="$(git -C "$G" merge-base HEAD main)"
check "resolve_base_ref finds the merge base" "$mb" "$BR"
if [ "$BR" != "$(git -C "$G" rev-parse HEAD)" ]; then ok "and it is NOT HEAD"; else bad "baseline is HEAD -- self-comparison"; fi

deny_gate "$G" "$BR" "$R/src/a.c" "src/a.c" >/dev/null 2>&1; rc=$?
check "a committed regression FAILS the gate" 1 "$rc"

# The clean twin: the same branch with the regression removed must pass.
printf '%s\n' 'void f(void) { }' 'void g(void) { }' >"$R/src/a.c"
commit clean-again
deny_gate "$G" "$BR" "$R/src/a.c" "src/a.c" >/dev/null 2>&1; rc=$?
check "clean code still PASSES the gate" 0 "$rc"
# Break twin for that control: one added symbol, uncommitted, must turn it red.
printf '%s\n' 'void f(void) { }' "void g(void) { $POOL *p; }" >"$R/src/a.c"
deny_gate "$G" "$BR" "$R/src/a.c" "src/a.c" >/dev/null 2>&1; rc=$?
check "break twin: one uncommitted new symbol FAILS" 1 "$rc"
git -C "$G" checkout -q -- src/a.c

# A detached checkout with no reachable base branch: the old code fell back to HEAD and the
# gate silently died. It must now refuse instead of reporting a pass.
D="$TMP/detached"
git -C "$G" checkout -q main
git clone -q --no-local --depth 1 --single-branch --branch main "$G" "$(native "$D")" >/dev/null 2>&1
if [ -d "$D/.git" ]; then
	GD="$(native "$D")"
	git -C "$GD" checkout -q --detach HEAD
	git -C "$GD" branch -q -D main >/dev/null 2>&1
	git -C "$GD" remote remove origin >/dev/null 2>&1
	printf '%s\n' 'void f(void) { }' "void g(void) { ${JS}A(x); }" >"$D/src/a.c"
	out="$(OOLITE_TIER_A_BASE= OOLITE_TIER_A_BASE_BRANCH=main resolve_base_ref "$GD" 2>"$TMP/err2")"
	rc=$?
	check "no base branch => resolve_base_ref FAILS" 1 "$rc"
	if [ -z "$out" ]; then ok "and prints no ref (never the string HEAD)"; else bad "printed a ref anyway: $out"; fi
	if grep -q 'never fail' "$TMP/err2"; then ok "and says why"; else bad "no diagnostic for the missing baseline"; fi
	# Discrimination: the legacy resolver answers the literal string HEAD here, which is what
	# turned the comparison into a tautology and made step 3 report PASS on a real regression.
	lb="$(OOLITE_TIER_A_BASE= LEGACY_base_ref "$GD")"
	if [ "$lb" = HEAD ]; then ok "legacy resolver returns HEAD here (the self-comparison)"; else bad "legacy returned '$lb' -- this case does not discriminate"; fi
else
	bad "could not build the detached clone probe"
fi

# THE BEAD'S OWN REPRO: OOLITE_TIER_A_BASE=HEAD with the regression already COMMITTED, and the
# working file therefore byte-identical to the blob at HEAD. Old code: NOW == BASE, exit 0.
git -C "$G" checkout -q bead/probe
printf '%s\n' 'void f(void) { }' "void g(void) { ${JS}A(x); $POOL *p; }" >"$R/src/a.c"
commit committed-regression
deny_gate "$G" "$(git -C "$G" rev-parse HEAD)" "$R/src/a.c" "src/a.c" >"$TMP/o3" 2>&1; rc=$?
check "baseline=HEAD, regression committed: gate FAILS (was exit 0)" 1 "$rc"
if grep -q 'using' "$TMP/o3"; then ok "and it says it stepped back off HEAD"; else bad "no diagnostic about the HEAD baseline"; fi
# Discrimination for the bead's own repro: reproduce the OLD comparison literally -- legacy
# count of the working file against the legacy count of the same path at the legacy baseline
# -- and assert it comes out EQUAL, i.e. reports a pass on this very regression.
ln_now="$(LEGACY_deny_count "$LIST" <"$R/src/a.c")"
ln_base="$(git -C "$G" show "HEAD:src/a.c" | LEGACY_deny_count "$LIST")"
if [ "$ln_now" = "$ln_base" ]; then ok "legacy compares $ln_now vs $ln_base and passes the regression"; else bad "legacy caught it ($ln_base -> $ln_now) -- no discrimination"; fi
# Break twin for that control: back the regression out, same baseline=HEAD path, must pass.
printf '%s\n' 'void f(void) { }' 'void g(void) { }' >"$R/src/a.c"
commit reverted-regression
deny_gate "$G" "$(git -C "$G" rev-parse HEAD)" "$R/src/a.c" "src/a.c" >/dev/null 2>&1
check "break twin: same path, clean commit, gate PASSES" 0 "$?"

# ...and where there is NO earlier commit of the file at all, HEAD-as-baseline is irreducibly
# vacuous, so the gate must refuse (2) rather than report a pass it cannot justify.
S="$TMP/single"; mkdir -p "$S/src" || exit 1; GS="$(native "$S")"
git -C "$GS" init -q -b main >/dev/null 2>&1
git -C "$GS" config user.email probe@local; git -C "$GS" config user.name probe
printf '%s\n' "void g(void) { ${JS}A(x); }" >"$S/src/a.c"
git -C "$GS" add -A >/dev/null 2>&1; git -C "$GS" commit -q -m only >/dev/null 2>&1
deny_gate "$GS" "$(git -C "$GS" rev-parse HEAD)" "$S/src/a.c" "src/a.c" >/dev/null 2>&1
check "no earlier commit of the file: gate refuses (2), never passes" 2 "$?"

echo "== the sourced gate must not switch errexit on in its caller =="
case "$-" in *e*) bad "errexit leaked into the probe shell" ;; *) ok "errexit still off after calling the gate" ;; esac

# A bogus baseline must be an error, not a silent zero baseline.
deny_gate "$G" 0000000000000000000000000000000000000000 "$R/src/a.c" "src/a.c" >/dev/null 2>&1
check "an unresolvable baseline exits 2" 2 "$?"
# A file absent at the baseline is the one legitimate default: compared against zero.
printf '%s\n' 'void h(void) { }' >"$R/src/new.c"
deny_gate "$G" "$BR" "$R/src/new.c" "src/new.c" >/dev/null 2>&1
check "a clean new file passes against a zero baseline" 0 "$?"
printf '%s\n' "void h(void) { ${JS}A(x); }" >"$R/src/new.c"
deny_gate "$G" "$BR" "$R/src/new.c" "src/new.c" >/dev/null 2>&1
check "a dirty new file fails against a zero baseline" 1 "$?"

echo
echo "probes: pass=$pass fail=$failn"
[ "$failn" -eq 0 ]
