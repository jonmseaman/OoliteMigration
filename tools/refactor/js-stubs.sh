#!/usr/bin/env bash
# tools/refactor/js-stubs.sh -- mechanical JS_* -> ooscript façade rewrite
# for the "stub / init / numeric-conversion" call-site pattern family.
#
# Covers, per the retarget map in upstream/oolite/src/Core/Scripting/ooscript/README.md
# and exactly as hand-retargeted in OOJSVector.mm (bead oo-sdz, the exemplar
# for this bead):
#
#   JS_PropertyStub / JS_EnumerateStub / JS_ResolveStub / JS_ConvertStub
#       -> nullptr          (no façade call; a nullptr ClassDef hook is the stub)
#   JS_InitClass(...)       -> ooscript::initClass(...) + OOJSROBJ(...) assignment
#   JS_NewNumberValue(...)  -> ooscript::newNumberValue(...)
#   JS_ValueToNumber(...)   -> ooscript::valueToNumber(...)
#   JS_ValueToBoolean(...)  -> ooscript::valueToBoolean(...)
#
# These eight identifiers account for ~40% of the tree's 3,828 JS_* call
# sites (ooscript/README.md's histogram: JS_NewNumberValue 144,
# JS_ValueToNumber 102, JS_ValueToBoolean 63, JS_InitClass 29, plus the
# stub family JS_PropertyStub 60 / JS_EnumerateStub 29 / JS_ResolveStub 32
# / JS_ConvertStub 32).
#
# This script does the SAME class of mechanical rewrite oo-sdz did by hand
# in OOJSVector.mm for these specific patterns; it does not retype JSClass
# to ClassDef, does not rename this/private locals, does not touch the
# OOJS_* argument-marshalling macros, and does not retarget any other
# façade function. Those remain per-file retarget work for the ~40 later
# 'Retarget JS_*' beads, which should run this script first and then hand-
# finish the rest.
#
# Usage:
#   tools/refactor/js-stubs.sh [--dry-run] <file> [<file> ...]
#
# Each file is rewritten in place (a backup is not made; run this against
# a git-tracked worktree so `git diff`/`git checkout` is your undo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PYTHON:-python3}"

if ! command -v "$PY" >/dev/null 2>&1; then
    PY=python
fi

# The python3 on PATH here may be a native Windows binary (MSYS path
# translation is disabled for it), so hand it a native path to the helper.
JS_STUBS_PY="$SCRIPT_DIR/js_stubs.py"
if command -v cygpath >/dev/null 2>&1; then
    JS_STUBS_PY="$(cygpath -m "$JS_STUBS_PY")"
fi

usage() {
    echo "usage: $(basename "$0") [--dry-run] <file> [<file> ...]" >&2
    exit 2
}

DRY_RUN=0
FILES=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage ;;
        *) FILES+=("$arg") ;;
    esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
    usage
fi

status=0
for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "js-stubs.sh: no such file: $f" >&2
        status=1
        continue
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        "$PY" "$JS_STUBS_PY" --dry-run "$f"
    else
        "$PY" "$JS_STUBS_PY" "$f"
    fi
done

exit "$status"
