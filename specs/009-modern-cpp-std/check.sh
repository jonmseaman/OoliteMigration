#!/usr/bin/env bash
# Spec 009 category searches (data-model.md *Converted category*). Run from oolite-dev.
#
#   check.sh <category> [--area <area>] [--count] [--unclassified]
#   check.sh bound <metric>@<milestone>
#
# Categories: alloc ownership thread oofnd enum tbl cast naming cstring cstring-types
# Areas: entities scripting materials sdl-debug core oofnd (default: all of src)
#
# A category prints its hits that are not on exceptions.md and exits 1 if there are any
# (--count prints the number instead and exits 0). cstring-types only reports, unless
# --unclassified, which prints hits that are neither excepted nor literal-typed and exits 1 if
# there are any. `bound` compares a baselines.md row with its base row (see tasks.md T003).
# Written for bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile.

set -u

SPEC_DIR=$(cd "$(dirname "$0")" && pwd)
EXCEPTIONS="$SPEC_DIR/exceptions.md"
BASELINES="$SPEC_DIR/baselines.md"

die() { echo "check.sh: $*" >&2; exit 2; }

if [ $# -lt 1 ]; then die "usage: check.sh <category> [--area A] [--count] [--unclassified] | bound <metric>@<milestone>"; fi

# --- bound ----------------------------------------------------------------------------------------
if [ "$1" = "bound" ]; then
  [ $# -eq 2 ] || die "usage: check.sh bound <metric>@<milestone>"
  [ -f "$BASELINES" ] || die "no $BASELINES"
  later="$2"
  base="${later%@*}"
  [ "$base" != "$later" ] || die "expected <metric>@<milestone>, got '$later'"
  awk -F'|' -v base="$base" -v later="$later" '
    function trim(s) { gsub(/^[ \t`]+|[ \t`]+$/, "", s); return s }
    NF >= 5 {
      name = trim($2)
      if (name == base)  { bm = trim($3); bs = trim($4); bb = trim($5); hb = 1 }
      if (name == later) { lm = trim($3); hl = 1 }
    }
    END {
      if (!hb) { print "check.sh: no base row " base > "/dev/stderr"; exit 2 }
      if (!hl) { print "check.sh: no row " later > "/dev/stderr"; exit 2 }
      if (bb == "lower")       ok = (lm + 0 <= bm + bs)
      else if (bb == "higher") ok = (lm + 0 >= bm - bs)
      else { print "check.sh: base row " base " has better=" bb > "/dev/stderr"; exit 2 }
      printf "%s: %s vs base %s (spread %s, %s is better): %s\n", later, lm, bm, bs, bb, ok ? "within bound" : "OUT OF BOUND"
      exit ok ? 0 : 1
    }' "$BASELINES"
  exit $?
fi

# --- categories -----------------------------------------------------------------------------------
category="$1"; shift
area=""; count=0; unclassified=0
while [ $# -gt 0 ]; do
  case "$1" in
    --area) [ $# -ge 2 ] || die "--area needs a value"; area="$2"; shift 2 ;;
    --count) count=1; shift ;;
    --unclassified) unclassified=1; shift ;;
    *) die "unknown option $1" ;;
  esac
done

[ -f mk.sh ] && [ -d src/Core ] || die "run from oolite-dev"

# Paths and globs for the area. Vendored code is always excluded.
paths=()
globs=(--glob '!src/Core/MiniZip/**' --glob '!src/SDL/EXRSnapshotSupport/**' --glob '!**/stb_*')
prefix_re='^src/(Core|SDL|oofnd)/'   # for clang-tidy output
case "$area" in
  "") paths=(src) ;;
  entities) paths=(src/Core/Entities); prefix_re='^src/Core/Entities/' ;;
  scripting) paths=(src/Core/Scripting); prefix_re='^src/Core/Scripting/' ;;
  materials)
    paths=(src/Core/Materials)
    for f in src/Core/OOOpenGL* src/Core/OOTexture*; do [ -e "$f" ] && paths+=("$f"); done
    prefix_re='^src/Core/(Materials/|OOOpenGL|OOTexture)' ;;
  sdl-debug) paths=(src/SDL src/Core/Debug); prefix_re='^src/(SDL|Core/Debug)/' ;;
  core)
    paths=(src/Core)
    globs+=(--glob '!src/Core/Entities/**' --glob '!src/Core/Scripting/**' --glob '!src/Core/Materials/**'
            --glob '!src/Core/Debug/**' --glob '!src/Core/OOOpenGL*' --glob '!src/Core/OOTexture*')
    prefix_re='^src/Core/' ;;
  oofnd) paths=(src/oofnd); prefix_re='^src/oofnd/' ;;
  *) die "unknown area '$area'" ;;
esac

search() {  # search <pcre> [extra rg args...]: prints file:line:text
  local re="$1"; shift
  rg -n --no-heading -P "$re" "${paths[@]}" "${globs[@]}" "$@" 2>/dev/null
}

tidy() {  # tidy <check>: prints file:line:message for one clang-tidy check over the area
  local check="$1" rct
  if [ -x /opt/homebrew/opt/llvm@22/bin/run-clang-tidy ]; then
    rct=/opt/homebrew/opt/llvm@22/bin/run-clang-tidy
    export PATH="/opt/homebrew/opt/llvm@22/bin:$PATH"
  else
    rct=$(command -v run-clang-tidy) || die "run-clang-tidy not found"
  fi
  [ -f compile_commands.json ] || die "no compile_commands.json: run ./mk.sh build test first"
  local root; root=$(pwd)
  "$rct" -p . -quiet -checks="-*,$check" 'src/(Core|SDL|oofnd)/.*\.cpp' 2>/dev/null \
    | sed -n -E "s#^${root}/([^:]+):([0-9]+):[0-9]+: (warning|error): (.*) \[${check}[^]]*\]\$#\1:\2:\4#p" \
    | grep -E "$prefix_re" | grep -v -E '/(MiniZip|EXRSnapshotSupport)/|stb_' | sort -u
}

case "$category" in
  alloc)     hits=$(search '(?<![\w:.>])(::|std::)?(malloc|calloc|realloc|free)\s*\(') ;;
  ownership) hits=$(search '\b(RefCounted|oo::Ref\b|oo::WeakRef|makeRef|leakRef|adopt\s*\()') ;;
  thread)    hits=$(search 'oo::thread::(detach|isMainThread)') ;;
  oofnd)     hits=$(search 'oo::(Expected|Unexpected)\b|\bNS(U?Integer|NotFound|TimeInterval)\b|\bCGFloat\b|oofnd/StdLib\.hpp' \
                      --glob '!src/Core/OOTypeEncodings.h' --glob '!src/Core/Entities/OOEntityObjectNamesTable.h') ;;
  enum)      hits=$(search '^\s*(typedef\s+)?enum\b(?!\s+class\b)') ;;
  tbl)       hits=$(for f in src/Core/Tables/*.tbl; do [ "$(basename "$f")" = OOOpenGLStates.tbl ] || echo "$f:1:table"; done) ;;
  cast)      hits=$(tidy google-readability-casting) ;;
  naming)    hits=$(tidy readability-identifier-naming) ;;
  cstring)   hits=$(search '\b(str(n?cpy|n?cat|n?cmp|casecmp|len|dup|r?chr|str|tok)|v?s?n?printf|ato[if]|strto[ld])\s*\(') ;;
  cstring-types) hits=$(search '\bconst\s+char\s*\*|\bchar\s+\w+\s*\[') ;;
  *) die "unknown category '$category'" ;;
esac

# Drop hits on the exceptions list (category, file, match).
filtered=$(printf '%s\n' "$hits" | awk -v cat="$category" -v exc="$EXCEPTIONS" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); gsub(/^`|`$/, "", s); return s }
  BEGIN {
    n = 0
    while ((getline line < exc) > 0) {
      if (line !~ /^\|/) continue
      split(line, c, "|")
      ec = trim(c[2]); ef = trim(c[3]); em = trim(c[4])
      if (ec == "category" || ec ~ /^-+$/ || ec == "") continue
      if (ec != cat) continue
      n++; F[n] = ef; M[n] = em
    }
  }
  NF == 0 || $0 == "" { next }
  {
    i = index($0, ":"); file = substr($0, 1, i - 1)
    keep = 1
    for (k = 1; k <= n; k++) if (F[k] == file && index($0, M[k]) > 0) { keep = 0; break }
    if (keep) print
  }')

if [ "$category" = "cstring-types" ] && [ $unclassified -eq 1 ]; then
  # Literal-typed declarations are fine: constexpr, or initialised from a string literal.
  filtered=$(printf '%s\n' "$filtered" | grep -v -E 'constexpr|=\s*"|\[\s*\]\s*=\s*\{' | sed '/^$/d')
fi

n=$(printf '%s\n' "$filtered" | sed '/^$/d' | wc -l | tr -d ' ')

if [ $count -eq 1 ]; then echo "$n"; exit 0; fi
[ "$n" -gt 0 ] && printf '%s\n' "$filtered" | sed '/^$/d'
if [ "$category" = "cstring-types" ] && [ $unclassified -eq 0 ]; then exit 0; fi
[ "$n" -eq 0 ]
