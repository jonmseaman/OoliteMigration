#!/usr/bin/env bash
#
# The GUI tier's runner — the one command the G1 DoD is allowed to be.
#
#     tools/gui-tier.sh                                  # the whole tier
#     tools/gui-tier.sh upstream/oolite/tests/gui/test_g1_exit_via_mouse.py
#     tools/gui-tier.sh -- -k exit_via_mouse             # extra pytest args after --
#
# It exists because `python3 -m pytest upstream/oolite/tests/gui/... -x -q` on its own cannot
# tell "G1 passed" from "G1 never ran". Two things had to be true before that command meant
# anything, and nothing in the repository made either of them true:
#
#   1. upstream/oolite/tests/gui/requirements.txt must actually be installed. It was installed
#      by nothing, so the missing-pyautogui case was the *expected* case.
#   2. The run must be on Windows with a real desktop, and must say so out loud when it is not.
#
# So this script installs the tier's requirements, then runs pytest with OO_GUI_REQUIRE=1, which
# turns conftest.py's not-applicable-platform skip into a failure. A green line from this script
# means the window opened; there is no configuration in which it means "skipped".
#
# Exit status is pytest's, except that a failed dependency install fails here first.

set -euo pipefail

# MSYS2's bash hands native Windows programs (python.exe, pip) MSYS-style /c/... paths that they
# cannot open, and path conversion is off in this environment. Everything passed to python is
# therefore made native, or kept relative to the repo root we cd into.
native() {
	if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUI_REL="upstream/oolite/tests/gui"
REQUIREMENTS_REL="$GUI_REL/requirements.txt"
REQUIREMENTS="$(native "$REPO_ROOT/upstream/oolite/tests/gui/requirements.txt")"

PYTHON="${OO_PYTHON:-python3}"
command -v "$PYTHON" >/dev/null 2>&1 || PYTHON=python
command -v "$PYTHON" >/dev/null 2>&1 || {
	echo "tools/gui-tier.sh: no python3 on PATH" >&2
	exit 1
}

[ -f "$REQUIREMENTS" ] || {
	echo "tools/gui-tier.sh: missing $REQUIREMENTS" >&2
	exit 1
}

# --- 1. Install the tier's requirements ------------------------------------------------------
#
# Skipped only by an explicit OO_GUI_SKIP_INSTALL=1 (an offline machine that has already done
# it). MSYS2's Python is externally managed, so --break-system-packages is required there and
# harmless elsewhere when pip understands it; older pips do not, hence the fallback.
if [ "${OO_GUI_SKIP_INSTALL:-0}" = "1" ]; then
	echo "tools/gui-tier.sh: OO_GUI_SKIP_INSTALL=1, not installing $REQUIREMENTS_REL"
else
	echo "tools/gui-tier.sh: installing $REQUIREMENTS_REL"
	"$PYTHON" -m pip install --break-system-packages -r "$REQUIREMENTS" \
		|| "$PYTHON" -m pip install -r "$REQUIREMENTS"
fi

# The install is only worth anything if it landed somewhere this interpreter can see, so prove
# the import before spending a game launch on discovering it cannot.
"$PYTHON" - <<'PY'
import sys
try:
    import pyautogui  # noqa: F401
except Exception as exc:
    sys.exit(
        "tools/gui-tier.sh: pyautogui still unimportable after installing requirements.txt "
        f"({exc.__class__.__name__}: {exc}). The GUI tier cannot run; refusing to report a pass."
    )
PY

# --- 2. Check the desktop preconditions BEFORE spending a game launch on them ----------------
#
# An elevated window owning the foreground makes the whole tier un-runnable: synthetic input goes
# to the focused window, and Windows forbids a medium-integrity process from taking the
# foreground away from a higher-integrity one (AttachThreadInput returns ERROR_ACCESS_DENIED
# across the UIPI boundary), so no retry inside the tests can ever succeed. Reported here, up
# front and by its own name, so an operator can tell "your desktop is unusable for GUI tests"
# from "G1 is broken" — the two failures a reviewer previously could not distinguish. It is a
# hard failure, not a skip: a run that reported success without exercising G1 would be a lie.
#
# It POLLS rather than sampling once. A single instantaneous sample makes a UAC prompt or an
# installer that owns the foreground for two seconds fail an entire accept.sh run on a healthy
# tree, for a condition that has already cleared. Only a blocker that PERSISTS for the tier's
# focus budget is a real one.
"$PYTHON" - <<PY
import sys
sys.path.insert(0, r"$(native "$REPO_ROOT/upstream/oolite/tests/gui")")
import time

import conftest

deadline = time.time() + conftest.FOCUS_TIMEOUT_SECONDS
blocker = conftest.describe_untakeable_foreground()
while blocker and time.time() < deadline:
    time.sleep(0.5)
    blocker = conftest.describe_untakeable_foreground()
if blocker:
    sys.exit(
        f"tools/gui-tier.sh: {conftest.DESKTOP_UNUSABLE_MARKER}: {blocker}.\n"
        f"It persisted for {conftest.FOCUS_TIMEOUT_SECONDS}s, so it is not a passing "
        "notification or installer. This is a DESKTOP problem, not a G1 failure: close or "
        "minimise that window (an elevated Task Manager is the usual culprit) and re-run. "
        "Refusing to start."
    )
PY

# --- 3. Run the tier, with skipping disarmed -------------------------------------------------
targets=()
passthrough=()
seen_dashdash=0
for arg in "$@"; do
	if [ "$seen_dashdash" = 1 ]; then
		passthrough+=("$arg")
	elif [ "$arg" = "--" ]; then
		seen_dashdash=1
	else
		targets+=("$arg")
	fi
done
[ ${#targets[@]} -gt 0 ] || targets=("$GUI_REL")

export OO_GUI_REQUIRE=1
cd "$REPO_ROOT"
exec "$PYTHON" -m pytest "${targets[@]}" -x -q "${passthrough[@]+"${passthrough[@]}"}"
