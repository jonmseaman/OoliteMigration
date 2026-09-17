#!/usr/bin/env bash
#
# tests/golden/run.sh <scenario> [options] - run ONE golden scenario in ONE native game process.
#
# No containers (ADR-0017): the game runs natively on this Windows machine with MSYS2's Mesa
# llvmpipe opengl32.dll staged beside the binary, exactly as upstream/oolite/tests/run_test_fn.sh
# does, and is driven over the debug-console TCP channel with the component tier's client
# (upstream/oolite/tests/component/console.py, ADR-0018).
#
# N of these run at once (N = the RAM budget in docs/infra/0-machines.md; see
# GOLDEN_MAX_CONCURRENCY below). Three things are therefore per-run, never shared:
#
#   * the console PORT      - ephemeral by default, so two invocations never pick the same one;
#   * the ARTIFACT dir      - timestamp + pid + port, so logs and snapshots cannot overwrite;
#   * the GNUstep PREFS root - src/SDL/main.m:119 points GNUSTEP_USERS_ROOT at the directory the
#     binary lives in, so every instance sharing one oolite.app races on one Defaults/oolite.plist.
#     golden_run.py gives each run its own staged app directory instead (links, not copies).
#
# This script is the thin, portable half: find the tree, find python, stage the Mesa DLLs, convert
# every path across the MSYS->native boundary with `cygpath -m` (a native python turns /c/... into
# C:/c/... and fails with WinError 3), then hand over to golden_run.py.

set -euo pipefail

# How many scenarios may run at once on this machine. docs/infra/0-machines.md's RAM budget row
# points at this constant: 64 GiB and one Mesa llvmpipe GL context per process. It is advisory -
# the runner does not queue - but tools that fan out should read it rather than invent a number.
GOLDEN_MAX_CONCURRENCY="${OO_GOLDEN_MAX_CONCURRENCY:-4}"

usage() {
	cat <<'EOF'
usage: tests/golden/run.sh <scenario> [options]

Runs one golden scenario as one native game process on its own console port, writing artifacts to
its own directory. Safe to run N times concurrently (N from docs/infra/0-machines.md).

Arguments:
  <scenario>            Scenario name. Optional settings are read from
                        tests/golden/scenarios/<scenario>/scenario.json:
                          seed            OO_RANDOM_SEED for the run (default 1)
                          settle_seconds  seconds of GAME clock to wait for before acting
                          load_save       .oolite-save handed to the game's -load
                          snapshot        true to capture a PNG (default true)
                          js              JS performed once the game is rendering

Options:
  --dry-run             Compute and print the run plan (port, artifact dir, staged app dir,
                        debugConfig.plist) without launching the game. Two invocations always
                        produce a different port and a different artifact directory.
  --app-dir <path>      oolite.app to run (default: $OO_APP_DIR, else the meson_test build)
  --run-dir <path>      Root for artifact directories (default: tests/golden/artifacts)
  --port <n>            Pin the console port instead of taking an ephemeral one
  --keep                Keep the staged app directory after the run (for debugging)
  --timeout <seconds>   Hard limit for the whole run (default 600)
  -h, --help            This text

Environment: OO_APP_DIR, OO_GOLDEN_RUNDIR, OO_CONSOLE_PORT, OO_GOLDEN_MAX_CONCURRENCY.
EOF
}

if [[ $# -eq 0 ]]; then
	usage >&2
	exit 2
fi
for arg in "$@"; do
	case "$arg" in
		-h|--help) usage; exit 0 ;;
	esac
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)
app_default="$repo_root/upstream/oolite/build/meson_test/oolite.app"

# Parse only what this half needs; everything else is forwarded verbatim.
scenario=""
app_dir="${OO_APP_DIR:-$app_default}"
dry_run=0
forward=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) dry_run=1; forward+=("$1"); shift ;;
		--app-dir) app_dir="$2"; shift 2 ;;
		--app-dir=*) app_dir="${1#*=}"; shift ;;
		--*) forward+=("$1"); [[ ${2-} && ${2-} != -* ]] && { forward+=("$2"); shift; }; shift ;;
		*) if [[ -z "$scenario" ]]; then scenario="$1"; else forward+=("$1"); fi; shift ;;
	esac
done

if [[ -z "$scenario" ]]; then
	echo "run.sh: no scenario given" >&2
	usage >&2
	exit 2
fi

PYTHON_CMD=""
for candidate in python3 python; do
	if command -v "$candidate" >/dev/null 2>&1 && "$candidate" --version >/dev/null 2>&1; then
		PYTHON_CMD="$candidate"
		break
	fi
done
if [[ -z "$PYTHON_CMD" ]]; then
	echo "run.sh: no python interpreter found" >&2
	exit 1
fi

# MSYS path -> native path at every boundary that a native binary (python, the game) will see.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# Mesa llvmpipe beside the binary, as run_test_fn.sh does. Two DLLs, not one: Mesa's opengl32.dll
# loads libgallium_wgl.dll at runtime and a missing one raises a MODAL dialog, which wedges an
# unattended run for ever instead of failing it. Skipped for --dry-run, which touches no build.
if [[ $dry_run -eq 0 && -d "$app_dir" && -n "${MINGW_PREFIX:-}" ]]; then
	for dll in opengl32.dll libgallium_wgl.dll; do
		src="${MINGW_PREFIX}/bin/${dll}"
		if [[ -f "$src" && ! -f "$app_dir/$dll" ]]; then
			echo "[*] staging $MSYSTEM Mesa $dll"
			cp "$src" "$app_dir/"
		fi
	done
fi

export OO_GOLDEN_MAX_CONCURRENCY="$GOLDEN_MAX_CONCURRENCY"
exec "$PYTHON_CMD" "$(native "$script_dir/golden_run.py")" \
	"$scenario" \
	--repo-root "$(native "$repo_root")" \
	--app-dir "$(native "$app_dir")" \
	"${forward[@]+"${forward[@]}"}"
