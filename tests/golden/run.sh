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
# GOLDEN_MAX_CONCURRENCY below). Three things are therefore per-run, never shared: the console
# PORT, the ARTIFACT dir, and the GNUstep PREFS root (src/SDL/main.m:119 points GNUSTEP_USERS_ROOT
# at the directory the binary lives in, so golden_run.py stages a private app dir per run).
#
# This script is the thin, portable half: find the tree, find python, stage the Mesa DLLs, convert
# every path across the MSYS->native boundary with `cygpath -m` (a native python turns /tmp/x into
# C:/tmp/x), then hand over to golden_run.py. EVERY path option is converted explicitly: a path
# reaching golden_run.py unconverted becomes the run's config_dir, which is handed to the GAME as
# OO_ADDITIONALADDONSDIRS - the game would not find the debugConfig.plist naming its port, would
# fall back to kOOTCPConsolePort=8563, and N concurrent runs would collide on that one port.
# golden_run.py re-checks anyway, because the environment (OO_GOLDEN_RUNDIR, OO_APP_DIR) bypasses
# this script entirely.

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
  --check-isolation     Hold --plan-count run plans at once (default 2, exactly what that many
                        concurrent invocations hold) and assert they cannot collide: distinct
                        ports, artifact/staged/config directories and run ids, and no MSYS path
                        anywhere in a plan. Launches nothing. Exit 0 means isolated.
  --app-dir <path>      oolite.app to run (default: $OO_APP_DIR, else the meson_test build)
  --run-dir <path>      Root for artifact directories (default: tests/golden/artifacts)
  --plan-count <n>      With --dry-run/--check-isolation: number of plans to hold at once
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

# Parse every option carrying a PATH; everything else is forwarded verbatim. --run-dir must be
# parsed here and not left to the catch-all: forwarded verbatim it reaches a native python as
# /tmp/x, which that python reads as C:/tmp/x (see the header).
scenario=""
app_dir="${OO_APP_DIR:-$app_default}"
run_dir="${OO_GOLDEN_RUNDIR:-}"
dry_run=0
forward=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) dry_run=1; forward+=("$1"); shift ;;
		--check-isolation) dry_run=1; forward+=("$1"); shift ;;
		--keep) forward+=("$1"); shift ;;
		--app-dir) app_dir="$2"; shift 2 ;;
		--app-dir=*) app_dir="${1#*=}"; shift ;;
		--run-dir) run_dir="$2"; shift 2 ;;
		--run-dir=*) run_dir="${1#*=}"; shift ;;
		--repo-root) repo_root="$2"; shift 2 ;;
		--repo-root=*) repo_root="${1#*=}"; shift ;;
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

# Mesa llvmpipe beside the binary, as run_test_fn.sh:28-33 does. Two DLLs, not one: Mesa's
# opengl32.dll loads libgallium_wgl.dll at runtime and a missing one raises a MODAL dialog, which
# wedges an unattended run for ever instead of failing it. The copy is UNCONDITIONAL, like the
# exemplar's: a stale opengl32.dll left beside the binary by an older MSYS2 would otherwise never
# be refreshed and the goldens would silently render on the old rasteriser. Concurrency-safe -
# parallel copies of an identical file to one target succeed, including while another process has
# it mapped. Skipped for --dry-run, which touches no build.
if [[ $dry_run -eq 0 && -d "$app_dir" && -n "${MINGW_PREFIX:-}" ]]; then
	for dll in opengl32.dll libgallium_wgl.dll; do
		src="${MINGW_PREFIX}/bin/${dll}"
		if [[ -f "$src" ]]; then
			echo "[*] staging $MSYSTEM Mesa $dll"
			cp -f "$src" "$app_dir/" || echo "[!] could not refresh $dll (in use?); keeping existing" >&2
		fi
	done
fi

export OO_GOLDEN_MAX_CONCURRENCY="$GOLDEN_MAX_CONCURRENCY"
# OO_GOLDEN_RUNDIR is consumed above and re-passed converted, so golden_run.py never sees the raw
# form through the environment either.
unset OO_GOLDEN_RUNDIR
run_dir_args=()
[[ -n "$run_dir" ]] && run_dir_args=(--run-dir "$(native "$run_dir")")
exec "$PYTHON_CMD" "$(native "$script_dir/golden_run.py")" \
	"$scenario" \
	--repo-root "$(native "$repo_root")" \
	--app-dir "$(native "$app_dir")" \
	"${run_dir_args[@]+"${run_dir_args[@]}"}" \
	"${forward[@]+"${forward[@]}"}"
