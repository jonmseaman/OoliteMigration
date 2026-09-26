#!/usr/bin/env bash
#
# Probe the REAL compile-database reader of tools/tier-a.sh (bead oo-3rb.97).
#
#     bash tools/tier-a-compdb-probe.sh
#
# THE DEFECT THIS GUARDS. On Windows meson writes compile_commands.json with every argument in
# double quotes and an embedded quote escaped as \" -- e.g. "-DOO_VERSION_FULL=\"0.0.0-fleet\"".
# tools/tier-a-compdb.py split that with shlex(posix=False), which does not honour \", so the
# define was cut at the escaped quote: clang-tidy saw OO_VERSION_FULL defined as a bare
# backslash plus a stray argument, and every CHANGED line using OO_VERSION_FULL / OO_BUILDER
# (upstream/oolite/src/Core/OOLogHeader.mm, "unexpected '@'" at @OO_BUILDER) failed Tier A.
#
# Nothing here re-implements the reader: every case runs tools/tier-a-compdb.py itself on a
# fixture compile database, or imports its split_windows, the way tools/tier-a-deny-probe.sh
# drives the real deny gate (bead oo-2ixr). Each defect case is also run through LEGACY_split,
# a verbatim copy of the pre-fix tokenizer, and the probe ASSERTS the legacy answer is wrong:
# if a future edit reverts the fix, those discrimination assertions go red with it. Clean twins
# (plain defines, backslash paths) must come out identical under both, so a reader that mangled
# everything would fail too.
#
# Scratch state is a per-run `mktemp -d` with an EXIT trap: the fleet runs several workers
# concurrently and a fixed scratch path would make them corrupt each other.
set -u

cd "$(dirname "$0")/.." || exit 1

pass=0
failn=0
ok()  { pass=$((pass+1));   printf 'ok   %s\n' "$*"; }
bad() { failn=$((failn+1)); printf 'FAIL %s\n' "$*"; }
check() { # check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then ok "$1 ($3)"; else bad "$1: want=$2 got=$3"; fi
}
differ() { # differ <label> <wrong-answer-that-must-not-match> <actual>
	if [ "$2" != "$3" ]; then ok "$1 (legacy gives $3)"; else bad "$1: legacy tokenizer now agrees ($3): the case no longer discriminates"; fi
}

# tier-a.sh calls `python` (native Windows on the fleet machine); fall back to python3 elsewhere.
PY=python
command -v "$PY" >/dev/null 2>&1 || PY=python3
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/tier-a-compdb-probe.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT
READER="$(native "$(pwd)/tools/tier-a-compdb.py")"

# Split one Windows-quoted command with the REAL split_windows; print the args joined by '|'.
real_split() {
	"$PY" - "$READER" "$1" <<'EOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("compdb", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
sys.stdout.write("|".join(mod.split_windows(sys.argv[2])))
EOF
}

# The pre-fix tokenizer, verbatim from tools/tier-a-compdb.py before bead oo-3rb.97.
LEGACY_split() {
	"$PY" - "$1" <<'EOF'
import shlex, sys
argv = shlex.split(sys.argv[1], posix=False)
argv = [a[1:-1] if len(a) > 1 and a[0] == a[-1] == '"' else a for a in argv]
sys.stdout.write("|".join(argv))
EOF
}

echo "== escaped-quote defines (the defect) =="
cmd='"-DOO_VERSION_FULL=\"0.0.0-fleet\""'
want='-DOO_VERSION_FULL="0.0.0-fleet"'
check  "version define is one arg with its quotes" "$want" "$(real_split "$cmd")"
differ "legacy splits the version define"          "$want" "$(LEGACY_split "$cmd")"

cmd='"-DOO_BUILDER=\"unknown\"" "-DWIN32"'
want='-DOO_BUILDER="unknown"|-DWIN32'
check  "builder define then a plain define" "$want" "$(real_split "$cmd")"
differ "legacy splits the builder define"   "$want" "$(LEGACY_split "$cmd")"

echo "== clean twins (must agree with legacy) =="
cmd='"clang++" "-DWIN32" "-DWINVER=0x0A00" -MD -c ../../src/Core/X.mm'
want='clang++|-DWIN32|-DWINVER=0x0A00|-MD|-c|../../src/Core/X.mm'
check "plain quoted and bare args"        "$want" "$(real_split "$cmd")"
check "legacy agrees on plain args"       "$want" "$(LEGACY_split "$cmd")"

cmd='"C:\Users\jon\ucrt64\bin/ccache.exe" "-IC:\Users\jon\include"'
want='C:\Users\jon\ucrt64\bin/ccache.exe|-IC:\Users\jon\include'
check "backslashes not before a quote stay literal" "$want" "$(real_split "$cmd")"
check "legacy agrees on backslash paths"            "$want" "$(LEGACY_split "$cmd")"

echo "== MSVC backslash-quote rules =="
check "2n backslashes + quote: n backslashes, quote closes" 'C:\dir\|next' "$(real_split '"C:\dir\\" next')"
check "2n+1 backslashes + quote: n backslashes, literal quote" 'a\"b' "$(real_split '"a\\\"b"')"
check "quoted space stays in the arg" 'a b|c' "$(real_split '"a b" c')"
check "empty quoted arg is kept" '|x' "$(real_split '"" x')"

echo "== end to end through tools/tier-a-compdb.py =="
# A fixture compile database shaped exactly like meson's Windows entry for OOLogHeader.mm.
"$PY" - "$(native "$TMP/compile_commands.json")" "$(native "$TMP/build/meson_test")" <<'EOF'
import json, sys
command = ('"C:\\msys2\\ucrt64\\bin/ccache.exe" "clang++" "-Isrc" "-I../../src/Core" '
           '"-DOO_VERSION_FULL=\\"0.0.0-fleet\\"" "-DOO_BUILD_DATE=\\"2026-09-23\\"" '
           '"-DOO_BUILDER=\\"unknown\\"" "-DWIN32" -MD -MQ src/o.p/Core_X.mm.obj '
           '-MF "src/o.p/Core_X.mm.obj.d" -o src/o.p/Core_X.mm.obj "-c" ../../src/Core/X.mm')
json.dump([{"directory": sys.argv[2], "command": command,
            "file": "../../src/Core/X.mm", "output": "src/o.p/Core_X.mm.obj"}],
          open(sys.argv[1], "w", encoding="utf-8"))
EOF
mkdir -p "$TMP/build/meson_test" "$TMP/src/Core"
out="$( cd "$TMP" && "$PY" "$READER" "$(native "$TMP/compile_commands.json")" src/Core/X.mm | tr '\0' '|' )"
check "reader emits target + clang args with intact defines" \
	'src/o.p/Core_X.mm.obj|-Isrc|-I../../src/Core|-DOO_VERSION_FULL="0.0.0-fleet"|-DOO_BUILD_DATE="2026-09-23"|-DOO_BUILDER="unknown"|-DWIN32' \
	"$out"

printf '\n%d passed, %d failed\n' "$pass" "$failn"
[ "$failn" -eq 0 ]
