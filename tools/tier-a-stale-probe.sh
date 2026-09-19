#!/usr/bin/env bash
#
# Probe the REAL stale-build-dir detector of tools/tier-a.sh (bead oo-1bf.8).
#
#     bash tools/tier-a-stale-probe.sh
#
# THE DEFECT THIS GUARDS. After bead oo-ss8 changed upstream/oolite/meson.build, the shared
# build dir's build.ninja was older than it, so tier-a's ninja call first ran ninja's
# REGENERATE_BUILD rule (`meson --internal regenerate`). Under that rule upstream's
# ShellScripts/common/get_version.sh:7-27 cannot identify meson as its parent (it shows as
# python.exe), meson dies at meson.build:5:13, and tier-a reported `FAIL (compile)` on EVERY
# file for ~20 hours. tier-a.sh now detects the condition on mtime and reconfigures through
# tools/build-windows.sh -- which supplies MINGW_PREFIX and the environment that guard needs --
# before ninja is ever asked to regenerate.
#
# Nothing here re-implements that detector: this sources tools/tier-a.sh with
# OOLITE_TIER_A_SOURCE_ONLY=1 and calls ITS buildsystem_files and stale_buildsystem_files, the
# way tools/tier-a-deny-probe.sh probes the deny-list gate (bead oo-2ixr). A probe that
# paraphrased the rule would pass while the rule was broken.
#
# Every case is a CONSTRUCTED CONDITION plus its clean twin, because the defect being closed is
# "a check that never fires". A detector that only ever reports 'current' would be caught by
# cases 2, 3 and 5; one that always reports 'stale' (which would reconfigure on every warm run
# and blow the 30 s budget) would be caught by cases 1 and 4.
#
# Scratch state is a per-run `mktemp -d` with an EXIT trap: the fleet runs several workers
# concurrently and a fixed scratch path would make them corrupt each other. Nothing here
# touches a real build directory, so the probe is safe to run at any time.
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

command -v stale_buildsystem_files >/dev/null 2>&1 \
	|| { printf 'FAIL tools/tier-a.sh did not export stale_buildsystem_files when sourced\n'; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/tier-a-stale-probe.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT

# A fake build directory shaped like meson's: build.ninja plus the introspection file whose
# contents name the build-system inputs. Paths are written exactly as meson writes them.
mk_builddir() { # mk_builddir <dir> <input-file>...
	local dir="$1"; shift
	mkdir -p "$dir/meson-info" || return 1
	{
		printf '[\n'
		local first=1 f
		for f in "$@"; do
			[ $first = 1 ] || printf ',\n'
			first=0
			printf '  "%s"' "$f"
		done
		printf '\n]\n'
	} > "$dir/meson-info/intro-buildsystem_files.json"
	: > "$dir/build.ninja"
}

count_lines() { grep -c . 2>/dev/null || true; }

# --- 1. A build dir NEWER than every input is current ----------------------------------------
D1="$TMP/d1"; mkdir -p "$D1"
: > "$TMP/a.build"; : > "$TMP/b.build"
sleep 1
mk_builddir "$D1" "$TMP/a.build" "$TMP/b.build"
check "current build dir reports no stale files" 0 \
	"$(stale_buildsystem_files "$D1" | count_lines)"

# --- 2. One input touched after build.ninja is detected, and NAMED ----------------------------
sleep 1
touch "$TMP/a.build"
OUT2="$(stale_buildsystem_files "$D1")"
check "one touched input is reported" 1 "$(printf '%s\n' "$OUT2" | count_lines)"
case "$OUT2" in
	*"$TMP/a.build"*) ok "the touched input is named in the report" ;;
	*) bad "the report does not name the touched input: $OUT2" ;;
esac
# The UNtouched input must not be reported: a detector that dumps its whole input list would
# satisfy the count check above by accident on a one-input tree.
case "$OUT2" in
	*"$TMP/b.build"*) bad "an untouched input was reported as stale: $OUT2" ;;
	*) ok "the untouched input is not reported" ;;
esac

# --- 3. A SUBDIR meson.build counts, not just the top-level one -------------------------------
# This is the case a hand-rolled `meson.build is newer` test would miss, and it is a real
# regeneration trigger: ninja lists every src/**/meson.build as an input of build.ninja.
D3="$TMP/d3"; mkdir -p "$TMP/sub"
: > "$TMP/top.build"; : > "$TMP/sub/meson.build"
sleep 1
mk_builddir "$D3" "$TMP/top.build" "$TMP/sub/meson.build"
check "fresh subdir build dir is current" 0 "$(stale_buildsystem_files "$D3" | count_lines)"
sleep 1
touch "$TMP/sub/meson.build"
check "a touched SUBDIR meson.build is detected" 1 \
	"$(stale_buildsystem_files "$D3" | count_lines)"

# --- 4. A missing input is not reported as stale ----------------------------------------------
# meson's list includes tools that may be absent from this shell's view (bash.exe, cat.exe by
# native path). A detector that treated 'cannot stat' as 'newer' would reconfigure on every
# single warm run, silently costing the 30 s budget rather than failing loudly.
D4="$TMP/d4"
: > "$TMP/present.build"
sleep 1
mk_builddir "$D4" "$TMP/present.build" "$TMP/definitely-absent-$$.build"
check "an absent input is not reported as stale" 0 \
	"$(stale_buildsystem_files "$D4" | count_lines)"

# --- 5. The introspection file is really what drives the answer -------------------------------
# Rewrite D1's intro file to name ONLY the untouched input. a.build is still newer than
# build.ninja on disk, so a detector ignoring the intro file and hard-coding a path set would
# still report 1 here. Expect 0.
printf '[\n  "%s"\n]\n' "$TMP/b.build" > "$D1/meson-info/intro-buildsystem_files.json"
check "the intro file drives the input set" 0 \
	"$(stale_buildsystem_files "$D1" | count_lines)"
check "buildsystem_files reads the intro file" 1 \
	"$(buildsystem_files "$D1" | count_lines)"

# --- 6. No build.ninja is NOT this detector's business ----------------------------------------
# tier-a.sh's configure-once block owns that case; reporting every input as stale here would
# mask a genuinely unconfigured build dir behind a reconfigure message.
D6="$TMP/d6"
mk_builddir "$D6" "$TMP/a.build"
rm -f "$D6/build.ninja"
check "a build dir with no build.ninja reports nothing" 0 \
	"$(stale_buildsystem_files "$D6" | count_lines)"

# --- 7. tier-a.sh really routes the remedy through tools/build-windows.sh ---------------------
# The whole point of the bead: the reconfigure must NOT be a bare `meson setup` or a bare
# ninja regenerate, because those are the two paths get_version.sh's guard rejects. Asserted on
# the source text because the remedy itself takes minutes to run.
if grep -q 'tools/build-windows\.sh" "\$BUILD_FLAVOUR"' tools/tier-a.sh; then
	ok "tier-a.sh invokes tools/build-windows.sh for the stale case"
else
	bad "tier-a.sh does not invoke tools/build-windows.sh for the stale case"
fi
if grep -q 'STALE_FILES="\$(stale_buildsystem_files "\$BUILD_DIR")"' tools/tier-a.sh; then
	ok "tier-a.sh consults the detector before step 1"
else
	bad "tier-a.sh does not consult stale_buildsystem_files"
fi

# --- 8. EVERY call site passes the build dir ---------------------------------------------------
# tier-a.sh runs under `set -u`, so a bare `stale_buildsystem_files` aborts the script with
# "$1: unbound variable" -- and the one call site that mattered was the POST-RECONFIGURE
# re-check, i.e. the code that only ever runs once the stale condition has already fired. It
# was shipped broken and passed every behavioural case above, because a probe that only calls
# the function correctly can never see a caller that does not. Both assertions are needed: the
# runtime one proves the argument really is mandatory, the source one proves nobody omits it.
( stale_buildsystem_files >/dev/null 2>&1 )
if [ $? -ne 0 ]; then
	ok "a bare stale_buildsystem_files call fails under set -u (the argument is mandatory)"
else
	bad "stale_buildsystem_files accepts no argument; case 8's source check proves nothing"
fi
BARE_CALLS="$(grep -nE '(^|[^_[:alnum:]])stale_buildsystem_files[[:space:]]*(\)|$|\|)' tools/tier-a.sh \
	| grep -v '^[0-9]*:stale_buildsystem_files() {' || true)"
if [ -z "$BARE_CALLS" ]; then
	ok "every stale_buildsystem_files call site passes a build dir"
else
	bad "a stale_buildsystem_files call site passes no build dir: $BARE_CALLS"
fi

printf '\ntier-a-stale-probe: %s ok, %s failed\n' "$pass" "$failn"
[ "$failn" -eq 0 ] || exit 1
