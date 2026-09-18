#!/usr/bin/env bash
# Scheduled READ-ONLY fleet reporter (bead oo-l7r0).
#
# The bead specifies "a scheduled task (claude -p --model claude-opus-5, read-only tools)".
# This script is that task's entry point, and it is deliberately split in two:
#
#   MODE=direct  (default)  run tools/fleet_reporter.py in-process.  Deterministic, offline,
#                           seconds, and it is what every acceptance line and every test runs.
#   MODE=claude             invoke `claude -p --model claude-opus-5` with an allowlist of
#                           read-only tools and the prompt in docs/fleet/reporter-prompt.md,
#                           asking it to run the same script and summarise the result.
#
# The seam exists because a delegated worker cannot honestly exercise the model leg: the CLI
# may be absent, unauthenticated, or far slower than an acceptance budget.  Report generation
# therefore does not depend on the model at all - the model leg only narrates it.  Nothing in
# the gate runs MODE=claude, and no claim in this repo asserts that it was run end to end.
#
# Read-only is not a promise made here; it is enforced inside fleet_reporter.py's ReadOnlyGuard
# (one permitted output path, an argv allowlist checked before exec) and proved by the negative
# tests in tests/fleet/test_fleet_reporter.py.
set -euo pipefail

MODE="${MODE:-direct}"
PY="$(command -v python3 || command -v python || echo /ucrt64/bin/python3)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

case "$MODE" in
  direct)
    exec "$PY" "$ROOT/tools/fleet_reporter.py" "$@"
    ;;
  claude)
    command -v claude >/dev/null 2>&1 || {
      echo "MODE=claude requested but 'claude' is not on PATH; use MODE=direct" >&2
      exit 127
    }
    prompt="$(cat "$ROOT/docs/fleet/reporter-prompt.md")"
    # --allowedTools is an allowlist: no Write, no Edit, no bd, no git mutation.  The guard
    # inside fleet_reporter.py is the real enforcement; this is defence in depth.
    exec claude -p --model claude-opus-5 \
      --allowedTools "Read,Glob,Grep,Bash(python3 tools/fleet_reporter.py*)" \
      "$prompt"
    ;;
  *)
    echo "unknown MODE=$MODE (expected: direct | claude)" >&2
    exit 2
    ;;
esac
