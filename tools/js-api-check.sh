#!/usr/bin/env bash
# Check the committed JS API conformance snapshot.
#
# Two modes, because the two useful questions have different prerequisites:
#
#   tools/js-api-check.sh          structural check. Offline, needs no game build, always
#                                  runnable: the snapshot parses as JSON, is byte-identical to
#                                  what a deterministic re-serialisation produces (sorted keys,
#                                  two-space indent, LF, trailing newline), contains no timestamp,
#                                  path, port or address, and still describes the classes and
#                                  global count the contract claims.
#
#   tools/js-api-check.sh --regen  the full DoD: regenerate from the live game and
#                                  `git diff --exit-code` the result. Requires a built oolite.app
#                                  and takes several minutes.
#
# The structural mode is what CI and the bead's acceptance run, because a clean checkout has no
# game binary; --regen is what a developer runs after touching the JS bindings.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
snapshot="$repo/oxp-contract/js-api-1.93.json"

if [ "${1:-}" = "--regen" ]; then
  "$here/js-api-snapshot.sh"
  git -C "$(cygpath -m "$repo" 2>/dev/null || printf '%s' "$repo")" \
    diff --exit-code -- oxp-contract/js-api-1.93.json
  echo "[+] regenerated snapshot is identical to the committed one"
  exit 0
fi

[ -f "$snapshot" ] || { echo "[!] missing $snapshot"; exit 1; }

python3 "$(cygpath -m "$here/js_api_check.py" 2>/dev/null || printf '%s' "$here/js_api_check.py")" \
  "$(cygpath -m "$snapshot" 2>/dev/null || printf '%s' "$snapshot")"
