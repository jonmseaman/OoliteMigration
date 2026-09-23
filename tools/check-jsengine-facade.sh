#!/usr/bin/env bash
# tools/check-jsengine-facade.sh — acceptance for the ooscript façade header (Phase 1 seam 1.1,
# bead oo-e7c), and since bead oo-7wx for the tree's independence from any one engine:
#
#   1. the header compiles on its own, twice-included, under -std=c++20 -Wall -Wextra -Werror;
#   2. the header names no engine type or function: it includes nothing but the C++ standard
#      library, and its code (comments stripped) mentions no JS_* / jsval / JSContext / JSObject;
#   3. no game source outside the backend (ooscript/JSEngine_quickjs.cpp) names an engine symbol
#      or header -- absolute, not baseline-relative: the Phase 1 exit gate's "zero JS_* symbols".
#
# The SpiderMonkey 1.8.5 backend and the steps that built it and ran its unit test left with the
# engine (bead oo-7wx); tests/unit/test_jsengine_spidermonkey.cpp stays in the tree, unbuilt, until
# Jon retires it (CLAUDE.md rule 2; bead filed). The QuickJS-ng backend's own acceptance is
# tools/check-jsengine-facade-quickjs.sh.
#
# Runs from the repo root in the MSYS2 UCRT64 shell. Offline; a few seconds.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
oo="$root/upstream/oolite"
hdr="$oo/src/Core/Scripting/ooscript/JSEngine.hpp"
prefix="${MINGW_PREFIX:-/ucrt64}"
CXX="${CXX:-clang++}"
work="${OO_FACADE_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/jsengine-facade.XXXXXX")}"
trap 'rm -rf "$work"' EXIT

flags=(-std=c++20 -Wall -Wextra -Werror)

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }

for f in "$hdr"; do
	[ -f "$f" ] || fail "missing $f"
done

step "1/3 header compiles on its own, twice-included, with no engine include path"
printf '#include "ooscript/JSEngine.hpp"\n#include "ooscript/JSEngine.hpp"\nint main() { ooscript::Value v{0}; return v.bits == 0 ? 0 : 1; }\n' > "$work/twice.cpp"
"$CXX" "${flags[@]}" -I"$oo/src/Core/Scripting" -fsyntax-only "$work/twice.cpp"

step "2/3 header is engine-neutral"
if grep -nE '^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"](js|mozjs|nspr|pr)' "$hdr"; then
	fail "the façade header includes an engine header"
fi
# Preprocess (through a wrapper, so #pragma once is not "in the main file"), keep only the lines
# that came from the header itself, and look for engine names.
printf '#include "ooscript/JSEngine.hpp"\n' > "$work/pp.cpp"
"$CXX" -std=c++20 -I"$oo/src/Core/Scripting" -E "$work/pp.cpp" \
	| awk -v h="$(basename "$hdr")" '/^# [0-9]+ "/ { keep = index($3, h) > 0; next } keep { print }' > "$work/hdr.i"
[ -s "$work/hdr.i" ] || fail "preprocessing produced no lines from $(basename "$hdr"); the engine-name scan would be vacuous"
if grep -nE '\bJS_[A-Za-z]+[[:space:]]*\(|\bjsval\b|\bjsid\b|\bJSContext\b|\bJSObject\b|\bJSString\b|\bJSClass\b|\bJSBool\b' "$work/hdr.i"; then
	fail "the façade header's code names engine types or functions"
fi

step "3/3 no game source outside the backend names an engine symbol"
engine_re='\bJS_[A-Za-z_]+|\bJSContext\b|\bjsval\b|\bJSRuntime\b|\bJSObject\b|jsapi\.h|jsdbgapi\.h|\bmozjs\b|\bnspr\b'
hits="$(grep -rnE "$engine_re" "$oo/src" --include='*.mm' --include='*.m' --include='*.h' --include='*.hpp' --include='*.c' --include='*.cpp' \
	| grep -v '/Scripting/ooscript/JSEngine_quickjs\.cpp:' || true)"
if [ -n "$hits" ]; then
	printf '%s\n' "$hits" | head -40 >&2
	fail "$(printf '%s\n' "$hits" | wc -l) line(s) outside the backend name an engine symbol"
fi

echo "PASS: ooscript façade header is engine-neutral and compiles clean; no game source outside the QuickJS-ng backend names an engine symbol"
