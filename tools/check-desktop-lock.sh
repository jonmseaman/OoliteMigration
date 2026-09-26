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
#   tests/golden/dump/run_dump.py  the golden STAGES' dump runner (tier-b/tier-c goldens, blessing):
#                                one game per scenario, launched only by the golden tier, with the
#                                same no-foreground profile its docstring argues. It is part of the
#                                golden harness CLAUDE.md exempts, so it is exempt with it.
#
# MEMBERS OF AN EXEMPT HARNESS (bead oo-hub0, proposed ADR-0046). Each golden scenario driver
# (tests/golden/combat.py, launch_dock.py, ...) is its own main program, but it launches its game
# THROUGH golden_run.py - golden_run.reserve_port / stage_app / the private debugConfig.plist - and
# is only ever run as one member of that harness's fan-out. Its launch is the harness's launch, so
# it inherits the harness's exemption instead of being listed. Membership is DERIVED, never listed
# (tools/launcher_scan.py --members-of): a spawner is a member of an exempt harness H only if it
# lives in H's own directory tree AND its code imports H's module (an ast import, which prose in a
# comment or docstring cannot fake). A spawner in tools/ that imports golden_run, or one in
# tests/golden/ that does not, is still an unclassified launcher and fails check 2. A member must
# not take the lock itself (check 3): it would serialise or deadlock the fan-out exactly as the
# harness would.
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
tools/oo-qwk5-probe.py
tests/golden/motion/motion_probe.py
tests/golden/motion/value_probe.py
upstream/oolite/tests/launch_snapshot.py
upstream/oolite/tests/component/conftest.py
upstream/oolite/tests/gui/conftest.py
"
EXEMPT_LAUNCHERS="
tests/golden/golden_run.py
tests/golden/dump/run_dump.py
upstream/oolite/tests/component/console.py
"
# Exempt launchers that are HARNESSES: every spawner that is one of their members (see the header)
# inherits the exemption. Each must also be in EXEMPT_LAUNCHERS.
EXEMPT_HARNESSES="
tests/golden/golden_run.py
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
# The list above is curated, so it has to be defended: a file that spawns the game and is in
# neither list is a launcher nobody has judged, and this check is the only thing that would ever
# notice.
#
# THE DETECTION LIVES IN tools/launcher_scan.py, which documents the rule and the two reviews
# that broke its predecessors. In one line: a launcher is A PROCESS-SPAWNING CALL WHOSE argv[0]
# RESOLVES TO THE GAME BINARY - keyed on semantics, not on a list of spellings.
#
#   * argv[0] ONLY. Mentioning the game in a later argument, an env var or a log path is not
#     launching it. That restriction is what stopped two MEASURED false positives (a meson build
#     helper holding PROJECT = "oolite", a log reader holding .../oolite.app/logs) from failing an
#     unrelated bead's acceptance on this shared gate.
#   * RESOLVED TRANSITIVELY, through everything this codebase uses to build a command line:
#     `name =`, `name +=`, `a, b =`, `self.name =`, `cmd.append/extend/insert`, and a function
#     whose return expression is game-valued. Review 2 evaded the previous version with all four
#     of the last ones - `cmd += [...]` is this repo's OWN house style (console.py:122).
#   * DebugConsole(...) counts wherever it appears: its constructor's job is to spawn the game.
#
# Scope: tools/, tests/ and upstream/oolite/tests/ - every file that is .py/.sh/.bat/.cmd OR
# carries a sh/bash/python shebang (tools/gui-lock and this file have no extension). Shell files
# get the same argv[0] rule in shell syntax, with leaders AND empty tokens stripped (so
# `start "" "%APP%\oolite.exe"` cannot hide behind an empty title) and `-c "..."` command strings
# re-scanned (so `bash -c "$APP/oolite.exe"` cannot hide inside a quoted argument).
# Upstream's own packaging scripts (upstream/oolite/ShellScripts, installers/win32/RunOolite.bat)
# are deliberately out of scope: they ship the game to end users, they are not fleet tooling, and
# nothing in a test run executes them.
#
# This file and the scanner exclude themselves - they necessarily quote every pattern they hunt
# for - and so does any match inside a comment. Prose mentioning oolite.exe never trips it.

step "2/4 no unclassified launcher"
known="$(printf '%s %s' "$LOCKED_LAUNCHERS" "$EXEMPT_LAUNCHERS" | tr '\n' ' ')"
spawners=$(python3 tools/launcher_scan.py tools tests upstream/oolite/tests) || fail=1
spawners=$(printf '%s' "$spawners" | tr -d '\r')
members=""
for h in $EXEMPT_HARNESSES; do
	case " $(printf '%s' "$EXEMPT_LAUNCHERS" | tr '\n' ' ') " in
		*" $h "*) ;;
		*) no "$h is listed as an exempt harness but is not in the exempt list" ;;
	esac
	got=$(python3 tools/launcher_scan.py --members-of "$h" $spawners) || fail=1
	got=$(printf '%s' "$got" | tr -d '\r')
	[ -n "$got" ] && ok "$(printf '%s\n' "$got" | wc -l | tr -d ' ') member(s) of $h inherit its exemption (they launch through it)"
	members="$members $got"
done
for f in $spawners; do
	case " $known $(printf '%s' "$members" | tr '\n' ' ') " in
		*" $f "*) ;;
		*) no "$f spawns the game but is in neither the locked nor the exempt list, nor a member of an exempt harness" ;;
	esac
done
# The detector must still SEE the launchers we already classified. If a refactor makes a known
# launcher invisible to it, the same blindness hides the next unclassified one, and check 2
# would go quiet instead of failing.
for f in $known; do
	case "
$spawners" in
		*"
$f"*) ;;
		*) no "$f is classified as a launcher but the spawn detector no longer sees it" ;;
	esac
done
[ "$fail" -eq 0 ] && ok "every game-spawning file is classified, and every classified one is still detected"

# --- 3. the exemptions are exempt ON PURPOSE, in writing ---------------------------------
#
# An exemption that is not argued in the file itself is indistinguishable from the bug: the
# next agent reading golden_run.py must be told why it does not lock, or they will either add
# a lock (and deadlock the fleet) or copy the omission into a tool that does need one.

step "3/4 each exemption is justified in its own file"
for f in $members; do
	if grep -q 'desktop_lock(' "$f"; then
		no "$f is a member of an exempt harness but takes the desktop lock; it would serialise or deadlock the fan-out"
	fi
done
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