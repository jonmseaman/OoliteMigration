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
# The list above is curated, so it has to be defended: a file that spawns the game and is in
# neither list is a launcher nobody has judged, and this check is the only thing that would ever
# notice.
#
# WHAT THIS USED TO DO, AND WHY IT WAS WORTHLESS. The first version grepped for the *string
# idiom* the existing launchers happen to use - `"oolite.exe" if IS_WINDOWS`. A review planted
# four rogue launchers and measured it: the ternary was caught, and THREE perfectly natural
# spellings were invisible while the check still printed PASS -
#   subprocess.Popen([os.path.join(APP, "oolite.exe"), "--no-splash"])   (the obvious one)
#   subprocess.Popen([APP + "/" + "oolite" + EXE])                       (name from variables)
#   subprocess.Popen("C:/app/oolite.app/oolite.exe --no-splash", shell=True)
# and `--include='*.py'` meant no .sh/.bat/.cmd wrapper was ever read at all. A guard that only
# recognises the code it was written against is not a guard.
#
# SO THE DETECTION IS KEYED ON THE SPAWN, not on one way of writing a filename:
#
#   * a process-spawning call - Popen/subprocess.run/call/check_call/check_output,
#     os.startfile/system/exec*/spawn*, or a shell command word - whose target mentions the game
#     (oolite.exe, oolite.app, a bare "oolite" argv[0], .../oolite); the target is followed
#     through variables to a fixpoint, so `bin_name = "oolite.exe" if ...` / `cmd = [f"./{bin_name}"]`
#     / `Popen(cmd)` is one launcher, not three unrelated lines.
#   * DebugConsole(...) - the shared transport whose whole job is to spawn the game. It is a
#     launcher wherever it appears, with or without a visible path.
#
# Scope: tools/, tests/ and upstream/oolite/tests/ - every file that is .py/.sh/.bat/.cmd OR
# carries a sh/bash/python shebang (tools/gui-lock and this file have no extension). Upstream's
# own packaging scripts (upstream/oolite/ShellScripts, installers/win32/RunOolite.bat) are
# deliberately out of scope: they ship the game to end users, they are not fleet tooling, and
# nothing in a test run executes them.
#
# This file excludes itself - it necessarily quotes every pattern it hunts for - and so does any
# match that is inside a comment. Prose mentioning oolite.exe never trips it.

step "2/4 no unclassified launcher"
known="$(printf '%s %s' "$LOCKED_LAUNCHERS" "$EXEMPT_LAUNCHERS" | tr '\n' ' ')"
spawners=$(SCAN_KNOWN="$known" python3 - tools tests upstream/oolite/tests <<'PY'
import os, re, sys

SELF = "tools/check-desktop-lock.sh"
# Files whose JOB is to quote launcher spellings. Excluding them is not a hole: neither ever
# runs the game (the rogue proof writes scratch files and deletes them), and if they were
# scanned this check could never describe what it hunts for.
SELF_REFERENTIAL = (SELF, "tools/desktop-lock-rogue-proof", "tools/desktop-lock-selftest")

# A call that starts a process. `run/call/check_call/check_output` only count with an explicit
# subprocess. prefix (a bare run() is any function); Popen is unambiguous enough on its own.
PY_SPAWN = re.compile(
    r"\b(?:subprocess\s*\.\s*(?:Popen|run|call|check_call|check_output)"
    r"|Popen"
    r"|os\s*\.\s*(?:startfile|system|popen|exec\w*|spawn\w*))\s*\(")
# The transport whose constructor spawns the game. A launcher wherever it appears.
TRANSPORT = re.compile(r"\bDebugConsole\s*\(")
# "this names the GAME BINARY" - not merely a path that has an `oolite` directory in it
# ($REPO/upstream/oolite/... is a source tree, not an executable). The binary is spelled
# oolite.exe, or lives in oolite.app/, or is the bare word "oolite"/"./oolite" in argv[0].
GAME = re.compile(r"oolite\.exe"
                  r"|oolite\.app[/\\]"
                  r"|['\"]\.?/?oolite['\"]"
                  r"|\./oolite(?![\w.])",
                  re.IGNORECASE)
ASSIGN = re.compile(r"^\s*(?:self\s*\.\s*)?([A-Za-z_]\w*)\s*(?::[^=\n]+)?=[^=]")
SH_ASSIGN = re.compile(r"^\s*(?:export\s+)?([A-Za-z_]\w*)=(.*)$")


def game_vars(text, assign_re, extract):
    """Names of variables that (transitively) hold the game binary or a command line for it."""
    found, changed = set(), True
    while changed:
        changed = False
        for line in text.splitlines():
            m = assign_re.match(line)
            if not m:
                continue
            rhs = extract(line, m)
            hit = GAME.search(rhs) or any(
                re.search(r"\b%s\b" % re.escape(v), rhs) for v in found)
            if hit and m.group(1) not in found:
                found.add(m.group(1))
                changed = True
    return found


def balanced(text, open_at):
    """The argument text of the call whose '(' is at open_at, to its matching ')'."""
    depth, i = 0, open_at
    while i < len(text) and i < open_at + 4000:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_at:i + 1]
        i += 1
    return text[open_at:open_at + 4000]


def strip_py_comments(text):
    return "\n".join(re.sub(r"(^|\s)#.*$", r"\1", ln) for ln in text.splitlines())


def spawns_python(text):
    body = strip_py_comments(text)
    if TRANSPORT.search(body):
        return True
    names = game_vars(body, ASSIGN, lambda line, m: line[m.end() - 1:])
    for m in PY_SPAWN.finditer(body):
        args = balanced(body, body.index("(", m.end() - 1))
        if GAME.search(args):
            return True
        if any(re.search(r"\b%s\b" % re.escape(v), args) for v in names):
            return True
    return False


SH_LEADERS = re.compile(
    r"^(?:exec|start|nohup|command|time|sudo|then|do|else|elif|if|while|until|"
    r"[A-Za-z_]\w*=\S*|/[cC]|cmd(?:\.exe)?|call)$")


def spawns_shell(text):
    names = game_vars(text, SH_ASSIGN, lambda line, m: m.group(2))
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.upper().startswith(("REM ", "::")):
            continue
        # Each pipeline/list segment gets its own command position.
        for seg in re.split(r"\|\||&&|[|;&]|\$\(|`", line):
            toks = seg.split()
            while toks and SH_LEADERS.match(toks[0].strip('"\'')):
                toks.pop(0)
            if not toks:
                continue
            word = toks[0].strip('"\'').lstrip("$").strip("{}")
            if GAME.search(word):
                return True
            if word in names or re.sub(r"[^\w].*$", "", word) in names:
                return True
    return False


roots = sys.argv[1:]
known = set(os.environ.get("SCAN_KNOWN", "").split())
out = []
for root in roots:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__", "build")]
        for name in sorted(filenames):
            path = os.path.join(dirpath, name).replace("\\", "/")
            ext = os.path.splitext(name)[1].lower()
            try:
                text = open(path, "r", encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if ext not in (".py", ".sh", ".bat", ".cmd"):
                head = text[:200].splitlines()
                if not (head and head[0].startswith("#!")
                        and re.search(r"\b(ba)?sh\b|python", head[0])):
                    continue
                ext = ".py" if "python" in head[0] else ".sh"
            if path in SELF_REFERENTIAL:
                continue
            hit = spawns_python(text) if ext == ".py" else spawns_shell(text)
            if hit:
                out.append(path)
print("\n".join(sorted(set(out))))
PY
)
spawners=$(printf '%s' "$spawners" | tr -d '\r')
for f in $spawners; do
	case " $known " in
		*" $f "*) ;;
		*) no "$f spawns the game but is in neither the locked nor the exempt list" ;;
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
