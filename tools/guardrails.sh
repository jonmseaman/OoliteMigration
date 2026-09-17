#!/usr/bin/env bash
#
# Guardrails — the four hard rules of CLAUDE.md, mechanically enforced (bead oo-ptc,
# docs/phases/0-safety-net.md item 0.11). Run by tools/tier-b.sh and tools/tier-c.sh, and
# runnable on its own:
#
#     tools/guardrails.sh                      # check this change against its base
#     tools/guardrails.sh --base <ref>         # ...against an explicit base
#     tools/guardrails.sh --explain            # print what each check enforces, exit 0
#
# THE FOUR RULES (CLAUDE.md "Hard rules" 1, 2, 3, 8):
#
#   goldens      no change under a protected golden path without a recorded re-bless approval
#   suppression  no NEW warning suppression (-Wno-*, #pragma ... diagnostic, unused-attribute)
#   tests        no test file deleted, renamed out of the test set, or emptied
#   deny-list    no NEW hit for a tools/deny-list.txt pattern in a changed source file
#
# ---------------------------------------------------------------------------------------
# DIFF vs TREE, decided per rule and not by habit
#
# Three of the four rules are statements about a CHANGE ("never modify", "never delete",
# "never add"), so they are evaluated against a BASE REF, not against the tree:
#
#   * checking the tree for "goldens/ is unmodified" is meaningless - a tree has no history;
#   * checking the tree for a warning suppression is permanently red, because
#     upstream/oolite/src/Core/OOCocoa.m and three other upstream files carry pre-existing
#     `#pragma ... diagnostic` lines that this migration did not add and may not delete
#     (rule 2 forbids touching them gratuitously). A tree-absolute check would therefore have
#     to be born with an exemption list the size of the defect, which is how a guard gets
#     bypassed rather than obeyed;
#   * the deny-list is baseline-relative for the reason tools/deny-list.txt states at length:
#     the tree legitimately contains 3,828 JS_* call sites today. Absolute means "fail always"
#     until Phase 1 and 2 land; relative means "fail on reintroduction", which is the regression
#     that actually exists.
#
# The one thing evaluated against the TREE is anti-vacuity (below), because "did my classifier
# match anything at all" is a question about the tree.
#
# BASE RESOLUTION, and why one rule covers both places this runs
#
# accept.sh evaluates a bead on a DETACHED, freshly merged checkout: it merges bead/<id> into
# the base branch with --no-ff and runs the acceptance commands there. `git merge-base HEAD main`
# is the right base in BOTH situations, and for the same reason: on that merged checkout the
# main tip is literally a parent of HEAD, so the merge base IS the main tip the merge started
# from; on a bead worktree it is the branch point. No special case is needed, and none should be
# written - "HEAD has two parents" does NOT mean "I am accept.sh", because a fresh bead worktree
# branched from main starts at main's last merge commit and would misresolve to HEAD^1.
# --base / $OO_GUARDRAILS_BASE override; HEAD^1 is the last-resort fallback for a merged tree in
# a clone with no main ref at all.
#
# The change is measured base-vs-WORKTREE (`git diff <base>` with no second ref) plus untracked
# files, so an agent's uncommitted violation is caught before it is committed. On the merged
# checkout the worktree is HEAD, so this is identical to base-vs-HEAD there.
#
# ANTI-VACUITY: a check that scans nothing must FAIL, not pass
#
# Every check states a fact about the tree that must hold for it to be capable of firing, and
# fails if it does not:
#
#   goldens      at least one protected path prefix must exist as a tracked path
#   suppression  the suppression matcher must match its built-in canary lines
#   tests        the test-file classifier must match at least one tracked file
#   deny-list    tools/deny-list.txt must exist, hold >= 1 pattern, and match its canary
#
# That is what stops the classic failure: a renamed directory turns a guard into a no-op and
# nothing ever goes red again.
#
# WHY GREP AND NOT AST, HERE
#
# Grep is the wrong tool when the forbidden string appears in prose ABOUT the rule - CLAUDE.md,
# every story, the reviewer prompt and this header all contain the literal text this forbids.
# Two things make grep correct here instead:
#
#   1. only ADDED LINES of a CHANGE are scanned, never file contents, so documentation that has
#      always said "-Wno-" is invisible; and
#   2. only CODE paths are scanned (see CODE_RE) - .md, .txt, .json/.jsonl and the bead database
#      are never scanned at all, which is where essentially all of that prose lives.
#
# For the residue - this file, its selftest, and tools/gen-stories.py, which emits the
# prohibition boilerplate into every story - the patterns below are written in bracket form
# ([-]Wno-, #[[:space:]]*pragma) so they do not match their own source text, and the three files
# are additionally listed in SCAN_EXEMPT with a reason. Both, because either one alone is a
# silent dependency: if a future edit breaks the bracket trick the exemption still holds, and if
# someone drops the exemption the bracket form still holds.
#
# DOES ANY OF THIS APPLY TO upstream/ ?
#
# Yes, for suppression, tests and the deny-list, and deliberately so: upstream/oolite is a git
# subtree of OUR fork and is the tree being migrated (CLAUDE.md, ADR-0017). It is where the
# migration's warnings, its tests and its JS_*/GNUstep symbols all live, so exempting it would
# exempt the entire project. Pre-existing upstream suppressions are not an obstacle because only
# added lines are scanned. (tools/check-file-modes.sh excludes upstream/ for the opposite and
# equally deliberate reason: file modes there come from upstream, so they are not ours to fix.)
set -u

cd "$(dirname "$0")/.." || exit 1

DENY_LIST="tools/deny-list.txt"
APPROVALS="tools/rebless-approvals.txt"

# Paths whose content is Jon's alone to change (CLAUDE.md rule 1). A change touching any of
# these needs a line in tools/rebless-approvals.txt naming the path.
PROTECTED_PREFIXES="goldens/ tests/golden/scenarios/"

# Extensions that are CODE for the purpose of the suppression and deny-list scans. Everything
# not listed here (.md, .txt, .json, .jsonl, .feature, .lock, ...) is prose or data and is not
# scanned for symbols: that is what keeps documentation about a rule from tripping the rule.
CODE_RE='\.(c|h|m|mm|cc|cpp|cxx|hpp|hh|inc|sh|py|build|ini|mk)$|(^|/)(Makefile|GNUmakefile|meson\.build|meson_options\.txt)$'

# Curated, and every entry carries its reason. A file is listed here only when its JOB is to
# contain the forbidden text.
SCAN_EXEMPT="
tools/guardrails.sh|the guard itself: this header quotes every construct it forbids
tools/guardrails-selftest|constructs the violations that prove the guard fires
tools/deny-list.txt|is the pattern list; every line is a deny-list hit by definition
tools/gen-stories.py|emits the verbatim prohibition block into every generated story
"

fail=0
note() { printf 'guardrails: %s\n' "$*" >&2; }
bad()  { fail=1; note "$*"; }

if [ "${1:-}" = "--explain" ]; then sed -n '2,120p' "$0"; exit 0; fi

BASE="${OO_GUARDRAILS_BASE:-}"
if [ "${1:-}" = "--base" ]; then BASE="${2:-}"; [ -n "$BASE" ] || { note "--base needs a ref"; exit 2; }; fi

if [ -z "$BASE" ]; then
  for cand in main origin/main; do
    if b=$(git merge-base HEAD "$cand" 2>/dev/null) && [ -n "$b" ]; then BASE="$b"; break; fi
  done
  if [ -z "$BASE" ] && [ "$(git rev-list --parents -n 1 HEAD 2>/dev/null | wc -w)" -gt 2 ]; then
    BASE="HEAD^1"
  fi
fi
[ -n "$BASE" ] || { note "cannot resolve a base ref (no merge parent, no main); pass --base"; exit 2; }
git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { note "base ref '$BASE' does not resolve"; exit 2; }
BASE_SHA=$(git rev-parse --short "$BASE")
note "base $BASE ($BASE_SHA)"

# --- the change ---------------------------------------------------------------------------
# "<status>\t<path>" (and "<status>\t<old>\t<new>" for a rename), base vs worktree, plus
# untracked files as adds.
CHANGE=$(git diff --name-status --find-renames "$BASE" --)
UNTRACKED=$(git ls-files --others --exclude-standard)
while IFS= read -r u; do [ -n "$u" ] && CHANGE="$CHANGE
A	$u"; done <<EOF
$UNTRACKED
EOF

changed_paths() {   # every path in the change, new side for renames
  printf '%s\n' "$CHANGE" | awk -F'\t' 'NF>=2 { print $NF }' | grep -v '^$'
}

is_exempt() {       # is_exempt <path>
  printf '%s' "$SCAN_EXEMPT" | grep -q "^$1|"
}

added_lines() {     # added_lines <path> ; the '+' side of the diff, or the whole file if untracked
  if git ls-files --error-unmatch -- "$1" >/dev/null 2>&1 || git cat-file -e "$BASE:$1" 2>/dev/null; then
    git diff --unified=0 "$BASE" -- "$1" | sed -n 's/^+//p' | sed '/^++ /d'
  else
    cat -- "$1" 2>/dev/null
  fi
}

# =============================================================================================
# 1. goldens/ — no change without a recorded re-bless approval
#
# Approval is a line in tools/rebless-approvals.txt naming the exact path, because "Jon's weekly
# re-bless queue" has to leave a mark in the tree to be checkable at all. Two properties make
# that more than a rubber stamp:
#
#   * a change may not approve ITSELF: if the same change also edits the approvals file, the
#     approval is refused. Adding an approval is a separate, human, reviewed commit.
#   * an approval names one path, not a directory, so it cannot be widened by accident.
# =============================================================================================
check_goldens() {
  local seen=0 p
  for p in $PROTECTED_PREFIXES; do
    if git ls-files -- "$p" | grep -q .; then seen=1; fi
  done
  [ "$seen" = 1 ] || { bad "goldens: no protected path ($PROTECTED_PREFIXES) exists in this tree - the protected-path list has rotted"; return; }

  local self_approved=0
  changed_paths | grep -qx "$APPROVALS" && self_approved=1

  local hits
  hits=$(changed_paths | grep -E "^($(printf '%s' "$PROTECTED_PREFIXES" | sed 's/ *$//;s/ /|/g'))")
  [ -n "$hits" ] || return 0

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$self_approved" = 1 ]; then
      bad "goldens: $p is changed by a change that also edits $APPROVALS - a change may not approve itself"
    elif [ -f "$APPROVALS" ] && grep -v '^[[:space:]]*#' "$APPROVALS" | awk 'NF{print $1}' | grep -qxF "$p"; then
      note "goldens: $p changed, re-bless approval on record - allowed"
    else
      bad "goldens: $p is under a protected golden path and has no re-bless approval in $APPROVALS (CLAUDE.md rule 1: re-blessing a golden is Jon's decision alone)"
    fi
  done <<EOF
$hits
EOF
}

# =============================================================================================
# 2. warning suppression — no NEW -Wno-*, #pragma diagnostic or unused-attribute
# =============================================================================================
sup_patterns() {
  # Bracket forms so these lines do not match themselves; see the header.
  printf '%s\n' \
    '[-]Wno-[A-Za-z0-9=_-]+' \
    '#[[:space:]]*pragma[[:space:]]+(GCC|clang)[[:space:]]+diagnostic' \
    '__attribute__[[:space:]]*\(\([^)]*unused' \
    '__unused\b' \
    '[-]Wno-error'
}

sup_match() { grep -E -n "$(sup_patterns | paste -sd'|' -)" ; }

check_suppression() {
  # Anti-vacuity: the matcher must fire on its own canaries, built by concatenation so the
  # literals never appear in this file.
  local canary1 canary2 canary3
  canary1="cflags = ['-W""no-unused-variable']"
  canary2="#pragma clang diag""nostic ignored \"-W""shadow\""
  canary3="static int x __attr""ibute__((unused));"
  local n
  n=$(printf '%s\n%s\n%s\n' "$canary1" "$canary2" "$canary3" | sup_match | wc -l)
  [ "$n" -eq 3 ] || { bad "suppression: matcher recognised $n/3 canary lines - the pattern set is broken and this check cannot fire"; return; }

  local p out
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s' "$p" | grep -qE "$CODE_RE" || continue
    is_exempt "$p" && continue
    [ -e "$p" ] || continue
    out=$(added_lines "$p" | sup_match)
    if [ -n "$out" ]; then
      bad "suppression: $p adds a warning suppression (CLAUDE.md rule 3: never silence a warning):"
      printf '%s\n' "$out" | sed 's/^/    /' >&2
    fi
  done <<EOF
$(changed_paths)
EOF
}

# =============================================================================================
# 3. tests — never deleted, renamed out of the test set, or emptied
#
# "Emptied" is measured, not eyeballed: a test file has a UNIT COUNT (scenarios and steps for a
# .feature, `def test_`/step decorators for a .py, assertions for a C unit test, and non-blank
# non-comment lines for anything else), and the count may not decrease. That covers the two ways
# a test is neutered without being deleted - gutting the body, and commenting the asserts out -
# without firing on an edit that only adds.
#
# ADR-0018 §5: .feature files and the component STEP LIBRARY are tests for this purpose. A step
# deleted from steps/ silently kills every scenario that used it, so the step library is
# classified as a test file in its own right.
# =============================================================================================
is_test_path() {   # is_test_path <path>
  case "$1" in
    tests/*|*/tests/*) return 0 ;;
  esac
  case "$(basename -- "$1")" in
    test_*.py|*_test.py|test_*.c|test_*.m|*.feature|conftest.py) return 0 ;;
  esac
  return 1
}

units() {          # units <path> ; reads content on stdin, prints a count
  local content; content=$(cat)
  local n=0
  case "$1" in
    *.feature)
      n=$(printf '%s\n' "$content" | grep -cE '^[[:space:]]*(Scenario|Scenario Outline|Example|Given|When|Then|And|But)\b') ;;
    *.py)
      n=$(printf '%s\n' "$content" | grep -cE '^[[:space:]]*(def[[:space:]]+test_|@(given|when|then|scenario|pytest\.mark))') ;;
    *.c|*.m|*.mm|*.cpp)
      n=$(printf '%s\n' "$content" | grep -cE '\b(assert|EXPECT_|ASSERT_|CHECK_)' ) ;;
  esac
  if [ "${n:-0}" -eq 0 ]; then
    n=$(printf '%s\n' "$content" | grep -cE '[^[:space:]]' )
  fi
  printf '%s' "$n"
}

check_tests() {
  local tracked
  tracked=$(git ls-files | while IFS= read -r f; do is_test_path "$f" && printf '%s\n' "$f"; done | wc -l)
  [ "$tracked" -gt 0 ] || { bad "tests: the test-file classifier matches 0 tracked files - it has rotted and this check cannot fire"; return; }
  note "tests: classifier matches $tracked tracked test files"

  local status old new
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    status=$(printf '%s' "$line" | cut -f1)
    case "$status" in
      D*)
        old=$(printf '%s' "$line" | cut -f2)
        is_test_path "$old" && bad "tests: $old is deleted (CLAUDE.md rule 2: never modify or delete a test)"
        ;;
      R*)
        old=$(printf '%s' "$line" | cut -f2); new=$(printf '%s' "$line" | cut -f3)
        if is_test_path "$old" && ! is_test_path "$new"; then
          bad "tests: $old is renamed to $new, out of the test set - that removes a test (CLAUDE.md rule 2)"
        fi
        ;;
      M*)
        new=$(printf '%s' "$line" | cut -f2)
        is_test_path "$new" || continue
        local before after
        before=$(git show "$BASE:$new" 2>/dev/null | units "$new")
        after=$(cat -- "$new" 2>/dev/null | units "$new")
        if [ "${after:-0}" -lt "${before:-0}" ]; then
          bad "tests: $new is emptied - test units $before -> $after (CLAUDE.md rule 2: never modify a test to make it pass)"
        fi
        ;;
    esac
  done <<EOF
$CHANGE
EOF
}

# =============================================================================================
# 4. deny-list — no NEW hit in a changed source file (CLAUDE.md rule 8)
#
# Per-file and baseline-relative, exactly as tools/tier-a.sh does it, so that the 3,828 call
# sites that legitimately exist today do not fail every run: what fails is a file growing a hit
# it did not have at the base.
# =============================================================================================
check_denylist() {
  [ -f "$DENY_LIST" ] || { bad "deny-list: $DENY_LIST is missing - this check cannot fire"; return; }
  local npat
  npat=$(grep -vE '^[[:space:]]*(#|$)' "$DENY_LIST" | wc -l)
  [ "$npat" -gt 0 ] || { bad "deny-list: $DENY_LIST holds 0 patterns - this check cannot fire"; return; }

  deny_count() {   # content on stdin -> total hits
    local text total=0 pattern hits
    text=$(cat)
    while IFS= read -r pattern; do
      case "$pattern" in ''|'#'*) continue ;; esac
      hits=$(printf '%s\n' "$text" | grep -cE "$pattern")
      total=$(( total + hits ))
    done < "$DENY_LIST"
    printf '%s' "$total"
  }

  # Anti-vacuity: known-bad text must score > 0 against the live pattern file.
  local canary
  canary=$(printf 'JSRuntime *rt;\n#import <Foundation/Foundation.h>\n' | deny_count)
  [ "${canary:-0}" -gt 0 ] || { bad "deny-list: canary text scores 0 against $DENY_LIST - the patterns are broken and this check cannot fire"; return; }
  note "deny-list: $npat patterns, canary scores $canary"

  local p now before
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s' "$p" | grep -qE "$CODE_RE" || continue
    is_exempt "$p" && continue
    [ -e "$p" ] || continue
    now=$(cat -- "$p" | deny_count)
    before=$(git show "$BASE:$p" 2>/dev/null | deny_count)
    if [ "${now:-0}" -gt "${before:-0}" ]; then
      bad "deny-list: $p reintroduces deny-listed symbols (${before} -> ${now} hits at $BASE_SHA):"
      while IFS= read -r pattern; do
        case "$pattern" in ''|'#'*) continue ;; esac
        grep -nE "$pattern" -- "$p" | sed 's/^/    /' >&2
      done < "$DENY_LIST"
    fi
  done <<EOF
$(changed_paths)
EOF
}

check_goldens
check_suppression
check_tests
check_denylist

if [ "$fail" -ne 0 ]; then
  note "FAIL"
  exit 1
fi
note "OK (goldens, suppression, tests, deny-list) against $BASE_SHA"
exit 0
