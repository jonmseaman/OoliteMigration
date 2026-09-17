#!/usr/bin/env bash
#
# The desktop-lock rule, enforced (bug oo-ccy9).
#
#     tools/check-desktop-lock.sh
#
# THE RULE: any tool in this repository that launches the game on the interactive desktop must
# take tools/gui-lock, the desktop mutex, for the duration of that launch. Not just the pytest
# GUI tier.
#
# Why it is not just the GUI tier's problem. On Windows the console-driven "headless" launches
# are not headless: SDL_VIDEODRIVER=offscreen is deliberately left unset there, because MSYS2's
# Mesa ships no EGL and the offscreen driver cannot create a context (component/console.py::_env).
# So a JS-API snapshot, a smoke launch and a component scenario each open a REAL window on the
# real desktop and can take the foreground - which one of them did, out from under a G1 click,
# once in 35 measured G1 runs on a clean tree.
#
# THE EXEMPTIONS, and they are the whole reason this is a curated list and not a blanket grep:
#
#   tests/golden/golden_run.py   runs N scenarios CONCURRENTLY by design
#                                (GOLDEN_MAX_CONCURRENCY, docs/infra/0-machines.md). gui-lock is
#                                exclusive, so locking here would serialise the fan-out into a
#                                queue of one, or deadlock a nested run. It never needs the
#                                FOREGROUND - no synthetic input, no clicks, readiness over the
#                                console socket, artifacts rendered game-side into
#                                OO_SNAPSHOTSDIR - and what must be exclusive between its runs
#                                (port, staged app dir, artifact dir) is already excluded
#                                per-resource. If it ever needs the foreground it stops being
#                                exempt AND must stop running N at a time.
#
#   component/console.py         the shared TRANSPORT, not a tier. It is spawned once per
#                                component scenario (locked by that tier's session-scoped
#                                desktop_lock fixture) and N times at once by the golden harness
#                                (exempt). A mutex in here would therefore deadlock the harness.
#                                The lock belongs to whoever decides how many games run at once.
#
#   gui/conftest.py              takes the lock already, in its own desktop_lock fixture, without
#                                going through tools/desktop_lock.py: that tier must keep working
#                                with no bash (see its _lock_reclaim_stale fallback).
#
# Surveyed and found to need nothing:
#
#   upstream/oolite/tests/run_test_fn.sh    launches nothing itself; it shells out to
#                                           launch_snapshot.py, which now takes the lock, so the
#                                           build's smoke step inherits it.
#   tools/check-enumeration-shuffle.sh      never launches the game at all - it compiles a unit
#                                           test, preprocesses a header and reads nm output. Its
#                                           own comments say the full-launch evidence comes from
#                                           launch_snapshot.py, which is the locked path.
#   tools/gui-tier.sh                       runs the GUI tier through pytest, which takes the
#                                           lock in its desktop_lock fixture.
#
# Four checks, all offline, all under a second, all runnable in accept.sh's build-less checkout.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo" || exit 1

fail=0
step() { printf '==> %s\n' "$*"; }
ok()   { printf '    PASS  %s\n' "$*"; }
no()   { printf '    FAIL  %s\n' "$*"; fail=1; }

# Every file that spawns the game binary, and what it must do about the lock.
#   lock:   must reference the desktop lock
#   exempt: must NOT take the lock, and must say why in its own text
LOCKED_LAUNCHERS="
tools/js_api_snapshot.py
tools/check-splash-off.py
upstream/oolite/tests/launch_snapshot.py
upstream/oolite/tests/component/conftest.py
upstream/oolite/tests/gui/conftest.py
"
EXEMPT_LAUNCHERS="
tests/golden/golden_run.py
upstream/oolite/tests/component/console.py
"

# --- 1. every locked launcher references the desktop lock --------------------------------

step "1/4 every desktop launcher takes tools/gui-lock"
for f in $LOCKED_LAUNCHERS; do
	[ -f "$f" ] || { no "$f is missing"; continue; }
	if grep -qE 'desktop_lock|gui-lock' "$f"; then
		ok "$f references the desktop lock"
	else
		no "$f launches the game on the desktop but never takes tools/gui-lock"
	fi
done

# --- 2. no NEW launcher has appeared unclassified ----------------------------------------
#
# The list above is curated, so it has to be defended: a file that spawns oolite.exe and is in
# neither list is a launcher nobody has judged, and this check is the only thing that would
# ever notice. Matched on the binary-name expression every launcher here uses.

step "2/4 no unclassified launcher"
known=" $(printf '%s %s' "$LOCKED_LAUNCHERS" "$EXEMPT_LAUNCHERS" | tr '\n' ' ') "
spawners=$(grep -rlE '"oolite\.exe" if|oolite\.exe" if IS_WINDOWS' \
	--include='*.py' tools tests upstream/oolite/tests 2>/dev/null | sed 's#\\#/#g' | sort -u)
for f in $spawners; do
	case "$known" in
		*" $f "*) ;;
		*) no "$f spawns the game but is in neither the locked nor the exempt list" ;;
	esac
done
[ "$fail" -eq 0 ] && ok "every game-spawning python file is classified"

# --- 3. the exemptions are exempt ON PURPOSE, in writing ---------------------------------
#
# An exemption that is not argued in the file itself is indistinguishable from the bug: the
# next agent reading golden_run.py must be told why it does not lock, or they will either add
# a lock (and deadlock the fleet) or copy the omission into a tool that does need one.

step "3/4 each exemption is justified in its own file"
for f in $EXEMPT_LAUNCHERS; do
	[ -f "$f" ] || { no "$f is missing"; continue; }
	if grep -q 'desktop_lock(' "$f"; then
		no "$f is listed exempt but takes the desktop lock; it would deadlock concurrent runs"
	elif grep -qiE 'NO DESKTOP LOCK|deadlock|would serialise' "$f"; then
		ok "$f states why it does not take the lock"
	else
		no "$f is exempt but does not say why in its own text"
	fi
done

# --- 4. the rule is written down where the next agent will look --------------------------

step "4/4 the rule is documented"
if grep -q 'gui-lock' CLAUDE.md; then
	ok "CLAUDE.md states the desktop-lock rule"
else
	no "CLAUDE.md does not state the desktop-lock rule"
fi
if grep -q 'check-desktop-lock' upstream/oolite/tests/gui/README.md; then
	ok "the GUI tier README points at this check"
else
	no "the GUI tier README does not point at this check"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "check-desktop-lock: PASS"
else
	echo "check-desktop-lock: FAIL"
fi
exit $fail
