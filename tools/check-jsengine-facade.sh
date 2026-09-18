#!/usr/bin/env bash
# tools/check-jsengine-facade.sh — acceptance for Phase 1 seam 1.1 (bead oo-e7c):
# the ooscript façade header and its SpiderMonkey 1.8.5 backend.
#
#   1. the header compiles on its own, twice-included, under -std=c++20 -Wall -Wextra -Werror;
#   2. the header names no engine type or function: it includes nothing but the C++ standard
#      library, and its code (comments stripped) mentions no JS_* / jsval / JSContext / JSObject;
#   3. the backend compiles with the game's defines and the same warning set;
#   4. the unit test links against the engine the game ships and passes;
#   5. every JS_* function with at least 7 call sites under upstream/oolite/src (the top-20
#      threshold on 2026-09-18) is named in the header's mapping table, so the table cannot
#      silently fall behind the tree.
#
# Runs from the repo root in the MSYS2 UCRT64 shell (the only place the game builds anyway).
# Offline; no game launch; about 20 s cold, mostly the 256-slot trampoline tables.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
oo="$root/upstream/oolite"
hdr="$oo/src/Core/Scripting/ooscript/JSEngine.hpp"
impl="$oo/src/Core/Scripting/ooscript/JSEngine_spidermonkey.cpp"
test_src="$oo/tests/unit/test_jsengine_spidermonkey.cpp"
prefix="${MINGW_PREFIX:-/ucrt64}"
CXX="${CXX:-clang++}"
work="${OO_FACADE_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/jsengine-facade.XXXXXX")}"
trap 'rm -rf "$work"' EXIT

flags=(-std=c++20 -Wall -Wextra -Werror)
# The engine ABI the game was built against (see the compile command in build/*/compile_commands.json).
defs=(-DXP_WIN -DWIN32 -DMOZ_TRACE_JSCALLS)
incs=(-I"$oo/src/Core/Scripting" -I"$prefix/include" -I"$prefix/include/nspr")
libs=(-L"$prefix/lib" -ljs -lnspr4 -lplds4 -lplc4 -lwinmm -lws2_32)

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }

for f in "$hdr" "$impl" "$test_src"; do
	[ -f "$f" ] || fail "missing $f"
done

step "1/5 header compiles on its own, twice-included, with no engine include path"
printf '#include "ooscript/JSEngine.hpp"\n#include "ooscript/JSEngine.hpp"\nint main() { ooscript::Value v{0}; return v.bits == 0 ? 0 : 1; }\n' > "$work/twice.cpp"
"$CXX" "${flags[@]}" -I"$oo/src/Core/Scripting" -fsyntax-only "$work/twice.cpp"

step "2/5 header is engine-neutral"
if grep -nE '^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"](js|mozjs|nspr|pr)' "$hdr"; then
	fail "the façade header includes an engine header"
fi
# Preprocess, keep only the lines that came from the header itself, and look for engine names.
"$CXX" -std=c++20 -E -x c++ "$hdr" \
	| awk -v h="$(basename "$hdr")" '/^# [0-9]+ "/ { keep = index($3, h) > 0; next } keep { print }' > "$work/hdr.i"
if grep -nE '\bJS_[A-Za-z]+[[:space:]]*\(|\bjsval\b|\bjsid\b|\bJSContext\b|\bJSObject\b|\bJSString\b|\bJSClass\b|\bJSBool\b' "$work/hdr.i"; then
	fail "the façade header's code names engine types or functions"
fi

step "3/5 backend compiles with the game's defines"
"$CXX" "${flags[@]}" "${defs[@]}" "${incs[@]}" -c "$impl" -o "$work/backend.o"

step "4/5 unit test builds against libjs and passes"
"$CXX" "${flags[@]}" "${defs[@]}" "${incs[@]}" "$test_src" "$work/backend.o" -o "$work/test_jsengine.exe" "${libs[@]}"
PATH="$prefix/bin:$PATH" "$work/test_jsengine.exe"

step "5/5 README.md's map covers every engine function with >= 7 call sites"
readme="$oo/src/Core/Scripting/ooscript/README.md"
[ -f "$readme" ] || fail "missing $readme"
missing=0
while read -r count name; do
	[ "$count" -ge 7 ] || continue
	if ! grep -q "\`$name\`" "$readme"; then
		echo "  not mapped: $name ($count sites)"
		missing=$((missing + 1))
	fi
done < <(grep -rhoE '\bJS_[A-Za-z]+\(' "$oo/src" --include='*.m' --include='*.h' | sed 's/($//' | sort | uniq -c | sort -rn | awk '{print $1, $2}')
[ "$missing" -eq 0 ] || fail "$missing heavily used engine function(s) are absent from README.md's map"

echo "PASS: ooscript façade header is engine-neutral and compiles clean; the SpiderMonkey backend builds and its unit test passes; README.md maps every engine function with >= 7 sites"
