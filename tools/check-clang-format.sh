#!/usr/bin/env bash
#
# Upstream's clang-format CI check (OoliteProject #751: .github/workflows/build-all.yaml job
# clang-format-check, jidicula/clang-format-action@v4.18.0 with clang-format-version '22' and
# check-path 'src'), run locally on upstream/oolite (bead oo-we7mm). Same file set (the action's
# default include regex: .c .cc .cpp .cxx .c++ .h .hh .hpp .hxx .h++ .ino .pde .proto .cu, so
# .m/.mm are not checked), same flags (--dry-run --Werror --style=file --fallback-style=llvm, the
# repository's .clang-format). The action runs clang-format 22 in its Docker image; this uses the
# clang-format on PATH and refuses a different major version.
#
#     bash tools/check-clang-format.sh          # exit 1 and list the files that are not formatted
#     bash tools/check-clang-format.sh --fix    # format them in place (formatting only)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/upstream/oolite"
CF="${CLANG_FORMAT:-clang-format}"
major="$("$CF" --version | sed -n 's/.*clang-format version \([0-9]*\)\..*/\1/p')"
[ "$major" = 22 ] || { echo "check-clang-format: need clang-format 22 (the workflow's), found '$major'" >&2; exit 2; }
cd "$ROOT"
mapfile -t files < <(find src -name .git -prune -o -regextype posix-egrep \
  -regex '^.*\.((((c|C)(c|pp|xx|\+\+)?$)|((h|H)h?(pp|xx|\+\+)?$))|(ino|pde|proto|cu))$' -print | sort)
[ "${#files[@]}" -gt 0 ] || { echo "check-clang-format: no source files under src" >&2; exit 2; }
if [ "${1:-}" = --fix ]; then
  "$CF" -i --style=file --fallback-style=llvm "${files[@]}"
  echo "check-clang-format: formatted ${#files[@]} files"; exit 0
fi
if out="$("$CF" --dry-run --Werror --style=file --fallback-style=llvm "${files[@]}" 2>&1)"; then
  echo "check-clang-format: OK (${#files[@]} files, clang-format $("$CF" --version | sed -n 's/.*version \([0-9.]*\).*/\1/p'))"
else
  printf '%s\n' "$out" | sed -n 's/\(.*\):[0-9][0-9]*:[0-9][0-9]*:.*$/\1/p' | sort -u | sed 's/^/not formatted: /'
  exit 1
fi
