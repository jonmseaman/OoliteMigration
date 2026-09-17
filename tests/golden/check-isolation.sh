#!/usr/bin/env bash
#
# tests/golden/check-isolation.sh - prove the runner's per-run isolation without launching a game.
#
# The real proof is N concurrent game processes, which needs a build and several GiB of RAM and so
# cannot run in a clean checkout. What can always run is the machinery that produces the isolation:
# ask the runner for two run plans held at the same time (exactly what two concurrent invocations
# hold) and assert the port, the artifact directory and the staged app directory all differ.
# run.sh is invoked through bash, so a checkout without the exec bit still works.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scenario="${1:-001}"

PYTHON_CMD=""
for candidate in python3 python; do
	if command -v "$candidate" >/dev/null 2>&1 && "$candidate" --version >/dev/null 2>&1; then
		PYTHON_CMD="$candidate"
		break
	fi
done
[[ -n "$PYTHON_CMD" ]] || { echo "check-isolation.sh: no python interpreter found" >&2; exit 1; }

# MSYS -> native at the boundary: a native python reads /c/... as a relative C:/c/... path.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

plans_file=$(mktemp)
trap 'rm -f "$plans_file"' EXIT
bash "$here/run.sh" "$scenario" --dry-run --plan-count 2 >"$plans_file"

"$PYTHON_CMD" "$(native "$here/check_isolation.py")" "$scenario" "$(native "$plans_file")"
