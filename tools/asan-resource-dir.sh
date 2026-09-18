#!/usr/bin/env bash
#
# tools/asan-resource-dir.sh -- make AddressSanitizer usable from the UCRT64 clang (bead oo-j4u).
#
#     tools/asan-resource-dir.sh [--print|--probe]
#
# --print  build (idempotently) the spliced resource directory and print its NATIVE path
# --probe  do that, then compile and run a deliberate heap-use-after-free and assert that
#          AddressSanitizer reports it.  Exits 0 only when ASan really fired.
#
# ------------------------------------------------------------------------------------------------
# WHY THIS FILE EXISTS -- the measured finding, not a guess
# ------------------------------------------------------------------------------------------------
#
# The toolchain this fleet builds with is MSYS2 UCRT64 clang 22.1.8
# (mingw-w64-ucrt-x86_64-clang).  It accepts -fsanitize=address and then fails at LINK time:
#
#   ld: cannot find .../lib/clang/22/lib/x86_64-w64-windows-gnu/libclang_rt.asan_dynamic.dll.a
#   ld: cannot find .../lib/clang/22/lib/x86_64-w64-windows-gnu/libclang_rt.asan_dynamic_runtime_thunk.a
#
# That is NOT a configuration mistake.  mingw-w64-ucrt-x86_64-compiler-rt 22.1.8-2 SHIPS NO ASAN
# AT ALL; its lib/windows/ contains only builtins, fuzzer, fuzzer_interceptors, fuzzer_no_main,
# profile and orc_rt.  The same upstream version built for the CLANG64 environment
# (mingw-w64-clang-x86_64-compiler-rt) DOES ship libclang_rt.asan_dynamic-x86_64.dll.a, its
# runtime thunk, and /clang64/bin/libclang_rt.asan_dynamic-x86_64.dll.  So the sanitizer exists
# for this exact clang; it is simply absent from the UCRT64 packaging.
#
# The splice: a private resource directory whose include/ is UCRT64's (so the UCRT headers and
# the compiler's own intrinsic headers are the ones the build already uses) and whose
# lib/x86_64-w64-windows-gnu/ holds the CLANG64 ASan archives under the names UCRT64 clang looks
# for.  -resource-dir points clang at it.  Two further facts were established the hard way:
#
#   * IT MUST LINK WITH LLD.  GNU ld rejects the thunk with ~10 "multiple definition of
#     __asan_option_detect_stack_use_after_return" errors (the archive member is pulled twice and
#     the COMDAT-selection directives are MSVC-style .drectve, which GNU ld prints as
#     "unrecognized").  -fuse-ld=lld links it clean.  The repo's own native file already selects
#     lld for c/cpp/objc, so the project build is already on the right linker.
#   * THE RUNTIME DLLs MUST BE ON PATH.  libclang_rt.asan_dynamic-x86_64.dll imports libc++.dll,
#     which lives in /clang64/bin.  Without that directory on PATH the process dies with
#     0xC0000515 / STATUS_DLL_NOT_FOUND-family exit codes and NO AddressSanitizer output -- which
#     is the same shape as this box's well-known missing-/ucrt64/bin failure (exit 3221225781)
#     and must not be confused with it.  ASAN_DLL_DIR below is that directory.
#
# Provisioning: the two CLANG64 packages are pinned in tools/windows-packages.lock and installed
# by tools/setup-windows.sh.  This script does not install anything; it fails loudly, naming the
# package, when they are absent, because a sanitizer stage that silently degrades to "no ASan"
# is exactly the vacuous green Tier C exists to prevent.

set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
die() { printf 'asan-resource-dir: %s\n' "$*" >&2; exit 2; }

UCRT_PREFIX="${UCRT_PREFIX:-/ucrt64}"
CLANG64_PREFIX="${CLANG64_PREFIX:-/clang64}"

# The DLL directory a sanitized binary needs at RUN time. Exported for callers.
ASAN_DLL_DIR="$CLANG64_PREFIX/bin"

MODE=print
while [ $# -gt 0 ]; do
  case "$1" in
    --print) MODE=print ;;
    --probe) MODE=probe ;;
    --dll-dir) MODE=dlldir ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
  shift
done

if [ "$MODE" = dlldir ]; then printf '%s\n' "$(native "$ASAN_DLL_DIR")"; exit 0; fi

command -v clang >/dev/null 2>&1 || die "no clang on PATH (MSYSTEM=${MSYSTEM:-unset}); this must run in a UCRT64 shell"

# The UCRT64 resource dir supplies include/; its ABSENCE means clang moved and the splice below
# would build a directory with no headers, which fails in a confusing place much later.
UCRT_RD="$(clang -print-resource-dir 2>/dev/null || true)"
[ -n "$UCRT_RD" ] && [ -d "$UCRT_RD/include" ] \
  || die "clang -print-resource-dir gave '$UCRT_RD', which has no include/; cannot splice"

CLANG_MAJOR="$(basename "$UCRT_RD")"
SRC_LIB="$CLANG64_PREFIX/lib/clang/$CLANG_MAJOR/lib/windows"
ASAN_IMPLIB="$SRC_LIB/libclang_rt.asan_dynamic-x86_64.dll.a"
ASAN_THUNK="$SRC_LIB/libclang_rt.asan_dynamic_runtime_thunk-x86_64.a"
ASAN_DLL="$CLANG64_PREFIX/bin/libclang_rt.asan_dynamic-x86_64.dll"

for f in "$ASAN_IMPLIB" "$ASAN_THUNK" "$ASAN_DLL"; do
  [ -f "$f" ] || die "missing $f -- AddressSanitizer is NOT packaged for UCRT64 clang; install the CLANG64 runtime with:
    pacman -S --needed mingw-w64-clang-x86_64-compiler-rt mingw-w64-clang-x86_64-libc++
  (both are pinned in tools/windows-packages.lock and installed by tools/setup-windows.sh)"
done

# The spliced tree lives outside the repository: it is a build artefact, and scratch inside the
# shared checkout blocks acceptance for the whole fleet (bead oo-4vdc).
RD_ROOT="${OO_ASAN_RESOURCE_DIR:-${TMPDIR:-/tmp}/oolite-asan-rd-$CLANG_MAJOR}"
LIBDIR="$RD_ROOT/lib/x86_64-w64-windows-gnu"
mkdir -p "$LIBDIR" || die "cannot create $RD_ROOT"

# include/ is UCRT64's, verbatim. Symlinks are unreliable here, so copy, but only when stale:
# a full copy is ~30 MB and this runs on every sanitizer build.
if [ ! -d "$RD_ROOT/include" ] || [ "$UCRT_RD/include" -nt "$RD_ROOT/include" ]; then
  rm -rf "$RD_ROOT/include"
  cp -r "$UCRT_RD/include" "$RD_ROOT/include" || die "could not copy $UCRT_RD/include"
fi
# Any other UCRT64 runtime archives (builtins, profile, ...) are kept, so a sanitized link that
# also needs builtins finds it in the same place a normal link would.
if [ -d "$UCRT_RD/lib/windows" ]; then
  for a in "$UCRT_RD"/lib/windows/*.a; do
    [ -f "$a" ] || continue
    b="$(basename "$a")"
    cp -n "$a" "$LIBDIR/${b/-x86_64.a/.a}" 2>/dev/null || true
  done
fi
cp -f "$ASAN_IMPLIB" "$LIBDIR/libclang_rt.asan_dynamic.dll.a" || die "copy failed: $ASAN_IMPLIB"
cp -f "$ASAN_THUNK"  "$LIBDIR/libclang_rt.asan_dynamic_runtime_thunk.a" || die "copy failed: $ASAN_THUNK"

RD_NATIVE="$(native "$RD_ROOT")"

if [ "$MODE" = print ]; then printf '%s\n' "$RD_NATIVE"; exit 0; fi

# ------------------------------------------------------------------------------------------------
# --probe: prove the toolchain really detects a memory error, end to end.
# ------------------------------------------------------------------------------------------------
#
# ANTI-VACUITY. Every cheaper signal here is satisfiable by a dead run: the link exiting 0 proves
# only that the archives were found; running the program and getting a nonzero exit proves only
# that something went wrong, and 0xC0000135-family DLL failures are ALSO nonzero. So the probe
# asserts the ASan report TEXT ("AddressSanitizer: heap-use-after-free"), and additionally runs a
# CLEAN control that must exit 0 and print nothing -- so "the checker matches everything" and
# "the compiler is not instrumenting" are both caught.

WORK="$(mktemp -d "${TMPDIR:-/tmp}/asan-probe-$$-XXXXXX")" || die "cannot create a probe dir"
trap 'rm -rf "$WORK" 2>/dev/null || true' EXIT

cat > "$WORK/uaf.c" <<'EOF'
#include <stdlib.h>
int main(void) { char *p = (char *)malloc(4); p[0] = 1; free(p); return p[1]; }
EOF
cat > "$WORK/ok.c" <<'EOF'
#include <stdlib.h>
int main(void) { char *p = (char *)malloc(4); p[0] = 1; int v = p[1] & 0; free(p); return v; }
EOF

CFLAGS_ASAN=(-fsanitize=address -fno-omit-frame-pointer -g -resource-dir "$RD_NATIVE" -fuse-ld=lld)

for t in uaf ok; do
  clang "${CFLAGS_ASAN[@]}" "$(native "$WORK/$t.c")" -o "$(native "$WORK/$t.exe")" \
      > "$WORK/$t.link.log" 2>&1 \
    || { sed -n '1,15p' "$WORK/$t.link.log" >&2
         die "the sanitized link FAILED for $t.c; see above (GNU ld cannot link the thunk -- is -fuse-ld=lld in effect?)"; }
done

# The runtime DLLs must be reachable or the process dies before main with no ASan output.
export PATH="$ASAN_DLL_DIR:$PATH"
# halt_on_error=1 + abort_on_error=0 keeps the exit status a plain 1 rather than a Windows
# exception code, so the two failure families stay distinguishable.
export ASAN_OPTIONS="${ASAN_OPTIONS:-halt_on_error=1:abort_on_error=0:detect_leaks=0}"

ok_rc=0
"$WORK/ok.exe" > "$WORK/ok.out" 2>&1 || ok_rc=$?
uaf_rc=0
"$WORK/uaf.exe" > "$WORK/uaf.out" 2>&1 || uaf_rc=$?

if [ "$ok_rc" -ne 0 ]; then
  sed -n '1,20p' "$WORK/ok.out" >&2
  # A DLL-not-found death looks like a crash but is a PATH problem; say which one this is.
  case "$ok_rc" in
    3221225781) die "the CLEAN control died with $ok_rc (0xC0000135, STATUS_DLL_NOT_FOUND): a runtime DLL is missing from PATH, not a sanitizer finding" ;;
  esac
  die "the CLEAN control exited $ok_rc; a sanitized binary that cannot even run a correct program makes every later ASan verdict meaningless"
fi
if grep -qi 'AddressSanitizer' "$WORK/ok.out"; then
  sed -n '1,20p' "$WORK/ok.out" >&2
  die "the CLEAN control produced an AddressSanitizer report; the probe cannot distinguish a real finding from noise"
fi

if [ "$uaf_rc" -eq 0 ]; then
  die "the deliberate heap-use-after-free exited 0 -- AddressSanitizer did NOT fire, so a sanitizer stage built on this would be a silent no-op"
fi
if ! grep -q 'ERROR: AddressSanitizer: heap-use-after-free' "$WORK/uaf.out"; then
  sed -n '1,25p' "$WORK/uaf.out" >&2
  case "$uaf_rc" in
    3221225781) die "the use-after-free probe died with 3221225781 (0xC0000135, STATUS_DLL_NOT_FOUND) and printed NO ASan report: this is the missing-DLL trap, not a sanitizer finding. $ASAN_DLL_DIR must be on PATH." ;;
  esac
  die "the use-after-free probe exited $uaf_rc but printed no 'ERROR: AddressSanitizer: heap-use-after-free'; a nonzero exit alone is not evidence the sanitizer works"
fi

printf 'asan: OK -- clean control exited 0 and silent; use-after-free caught (exit %s)\n' "$uaf_rc"
printf 'asan: %s\n' "$(grep -m1 'ERROR: AddressSanitizer' "$WORK/uaf.out")"
printf 'asan: resource-dir %s\n' "$RD_NATIVE"
printf 'asan: runtime DLLs %s\n' "$(native "$ASAN_DLL_DIR")"
