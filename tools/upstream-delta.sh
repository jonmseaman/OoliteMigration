#!/usr/bin/env bash
#
# The per-module freeze policy (architecture §6.3 item 5, bead oo-kih, proposed ADR-0059), made
# executable. docs/UPSTREAM_DELTA.md is its data: the sync baseline, the module table, and one row
# per upstream commit that touched a frozen module and must be ported by hand.
#
#     bash tools/upstream-delta.sh --check                  # the file is well formed and in force
#     bash tools/upstream-delta.sh --frozen                 # frozen modules, one src/ path per line
#     bash tools/upstream-delta.sh --pending <upstream-ref> # upstream commits since the baseline
#                                                           # that touch a frozen module
#     bash tools/upstream-delta.sh --restore-frozen <pre-sync-commit>
#                                                           # after `git subtree pull`, put every
#                                                           # frozen module back as it was
#     bash tools/upstream-delta.sh --file <path> --check    # check another copy (the probe uses it)
#
# --check fails when: the baseline is missing or not a commit id; a module directory under
# upstream/oolite/src that holds source is not in the table (a new directory must be classified);
# a row names a directory that does not exist or a status other than frozen/open; a module that
# already holds Phase 3 work (a cxx:: class or an +ObjCBridge facade) is not frozen; a delta row
# has a malformed commit id, an unknown status, or (to-port/ported) no bead id. Offline.
#
# A module is one directory, not its subdirectories: src/Core and src/Core/Entities are separate.
# The upstream-tracker task (docs/fleet/upstream-tracker-prompt.md) is the only caller of
# --pending and --restore-frozen.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/upstream/oolite/src"
FILE="$REPO_ROOT/docs/UPSTREAM_DELTA.md"

die() { printf 'upstream-delta: %s\n' "$*" >&2; exit 1; }

mode=""; arg=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE="${2:?--file needs a path}"; shift 2 ;;
    --check|--frozen) mode="$1"; shift ;;
    --pending|--restore-frozen) mode="$1"; arg="${2:?$1 needs a commit}"; shift 2 ;;
    *) die "unknown argument: $1 (see the header of $0)" ;;
  esac
done
[ -n "$mode" ] || mode=--check
[ -f "$FILE" ] || die "no $FILE"

# The lines between <!-- <name>:begin --> and <!-- <name>:end -->.
section() {
  awk -v b="<!-- $1:begin -->" -v e="<!-- $1:end -->" '$0 == e { on = 0 } on { print } $0 == b { on = 1 }' "$FILE"
}

# The module table: rows "| `src/<dir>` | frozen|open | ... |". Printed as "<dir> <status>".
modules() {
  section modules | sed -n 's/^| *`src\/\([^`]*\)` *| *\([a-z-]*\) *|.*/\1 \2/p'
}

# The delta table's data rows (its header row and separator row dropped).
delta_rows() {
  section delta | grep -E '^\|' | tail -n +3 || true
}

baseline() {
  sed -n 's/^Baseline: *`\([0-9a-f]*\)`.*/\1/p' "$FILE" | head -n 1
}

# Every directory under src that directly holds a source file, relative to src.
source_dirs() {
  (cd "$SRC" && find . -type f \( -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.c' \
     -o -name '*.cpp' -o -name '*.hpp' -o -name '*.tbl' \) -printf '%h\n' | sed 's|^\./||; s|^\.$||' \
     | grep -v '^$' | sort -u)
}

# A module that already holds Phase 3 work: an +ObjCBridge facade or a cxx:: class.
has_phase3_work() {
  local d="$SRC/$1"
  compgen -G "$d/*+ObjCBridge.*" >/dev/null && return 0
  grep -qsE '^namespace cxx' "$d"/*.h "$d"/*.hpp "$d"/*.mm "$d"/*.cpp 2>/dev/null
}

check() {
  local fail=0 b dir status
  b="$(baseline)"
  [[ "$b" =~ ^[0-9a-f]{7,40}$ ]] || { echo "FAIL: no 'Baseline: \`<upstream commit>\`' line"; fail=1; }

  declare -A seen=()
  while read -r dir status; do
    [ -n "$dir" ] || continue
    [ -z "${seen[$dir]:-}" ] || { echo "FAIL: src/$dir is listed twice"; fail=1; }
    seen[$dir]="$status"
    [ -d "$SRC/$dir" ] || { echo "FAIL: src/$dir is in the table but is not a directory"; fail=1; }
    case "$status" in
      frozen) ;;
      open) if has_phase3_work "$dir"; then
              echo "FAIL: src/$dir holds Phase 3 work (cxx:: class or +ObjCBridge) but is 'open'; freeze it"; fail=1
            fi ;;
      *) echo "FAIL: src/$dir has status '$status' (frozen or open)"; fail=1 ;;
    esac
  done < <(modules)
  [ "${#seen[@]}" -gt 0 ] || { echo "FAIL: the module table is empty"; fail=1; }

  while read -r dir; do
    [ -n "${seen[$dir]:-}" ] || { echo "FAIL: src/$dir holds source but is not in the module table"; fail=1; }
  done < <(source_dirs)

  # Delta rows: "| <sha> | <date> | `src/<dir>` | <subject> | <status> | <bead or -> |".
  local n=0 line sha mod st bead
  while IFS= read -r line; do
    n=$((n + 1))
    sha="$(awk -F'|' '{gsub(/ /,"",$2); print $2}' <<<"$line")"
    mod="$(awk -F'|' '{print $4}' <<<"$line" | sed -n 's/.*`src\/\([^`]*\)`.*/\1/p')"
    st="$(awk -F'|' '{gsub(/ /,"",$6); print $6}' <<<"$line")"
    bead="$(awk -F'|' '{gsub(/ /,"",$7); print $7}' <<<"$line")"
    [[ "$sha" =~ ^[0-9a-f]{7,40}$ ]] || { echo "FAIL: delta row $n: '$sha' is not a commit id"; fail=1; }
    [ "${seen[$mod]:-}" = frozen ] || { echo "FAIL: delta row $n: src/$mod is not a frozen module"; fail=1; }
    case "$st" in
      to-port|ported) [[ "$bead" =~ ^oo-[0-9a-z.]+$ ]] || { echo "FAIL: delta row $n: '$st' needs a bead id"; fail=1; } ;;
      not-applicable) ;;
      *) echo "FAIL: delta row $n: status '$st' (to-port, ported or not-applicable)"; fail=1 ;;
    esac
  done < <(delta_rows)

  [ "$fail" -eq 0 ] || exit 1
  echo "upstream-delta: OK ($(modules | grep -c ' frozen$') frozen, $(modules | grep -c ' open$') open, $n delta row(s), baseline $b)"
}

# Git pathspecs for the frozen modules, relative to a tree rooted at the upstream repo ($1 = prefix).
frozen_pathspecs() {
  local prefix="$1" dir status
  while read -r dir status; do
    [ "$status" = frozen ] && printf ':(glob)%ssrc/%s/*\n' "$prefix" "$dir"
  done < <(modules)
}

case "$mode" in
  --check) check ;;
  --frozen) modules | awk '$2 == "frozen" { print "src/" $1 }' ;;
  --pending)
    b="$(baseline)"; [ -n "$b" ] || die "no baseline in $FILE"
    mapfile -t specs < <(frozen_pathspecs "")
    git -C "$REPO_ROOT" log --reverse --format='%h %ad %s' --date=short "$b..$arg" -- "${specs[@]}"
    ;;
  --restore-frozen)
    git -C "$REPO_ROOT" rev-parse --verify --quiet "$arg^{commit}" >/dev/null || die "not a commit: $arg"
    mapfile -t specs < <(frozen_pathspecs "upstream/oolite/")
    # Files upstream added inside a frozen module go; everything else in it returns to $arg.
    git -C "$REPO_ROOT" diff --name-only --diff-filter=A "$arg" -- "${specs[@]}" \
      | while read -r f; do git -C "$REPO_ROOT" rm -q --cached -- "$f"; rm -f -- "$REPO_ROOT/$f"; done
    git -C "$REPO_ROOT" checkout "$arg" -- "${specs[@]}"
    git -C "$REPO_ROOT" diff --cached --quiet "$arg" -- "${specs[@]}" \
      || die "frozen modules still differ from $arg after restoring"
    echo "upstream-delta: frozen modules restored to $arg"
    ;;
esac
