#!/usr/bin/env bash
# oo-5ggu acceptance line 2: every translation unit of the golden build carries the pinned flags.
#
# Configures a SCRATCH meson build dir from the source tree and asserts the flags across ALL
# translation units - not a sample, not the shared build dir, which may be anything by the time
# this runs. Configuring is enough: compile_commands.json is the exact command lines ninja would
# run, so this costs seconds rather than a full compile, and it works in accept.sh's throwaway
# checkout, which contains no build.
#
# THROUGH A SHELL, DELIBERATELY: meson.build:5 runs get_version.sh, which identifies its caller by
# walking the parent process chain and rejects a bare subprocess with EMPTY diagnostics that read
# like a repo defect (fleet learnings oo-djn, oo-ss8). check_build_flags.configure() does exactly
# that and sets MINGW_PREFIX/MSYSTEM, and passes -Ddebug=false, without which meson appends -O0
# AFTER -O2 and every TU really compiles at -O0.
set -euo pipefail
export PATH=/ucrt64/bin:$PATH

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)

SCRATCH="${OO_FLAGCHECK_DIR:-${LOCALAPPDATA:-/tmp}/Temp/oo5ggu-flagcheck-$$}"
rm -rf "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

"$PY" "$(cygpath -m "$REPO_ROOT/tests/golden/check_build_flags.py")" \
    --configure-from "$(cygpath -m "$REPO_ROOT/upstream/oolite")" \
    --build-dir "$(cygpath -m "$SCRATCH")"
