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
#   suppression  no NEW warning suppression (-Wno-*, #pragma/_Pragma diagnostic, unused-attribute)
#   tests        no test file deleted, renamed out of the COLLECTED set, or gutted
#   deny-list    no NEW hit for a tools/deny-list.txt pattern in a changed source file
#
# ---------------------------------------------------------------------------------------
# RENAMES ARE FIRST-CLASS, AND THAT IS THE MOST IMPORTANT THING IN THIS FILE
#
# This migration renames files BY DESIGN: the whole .m -> .cpp sweep of Phases 1 and 2 is
# renames, and the tree carries 3,828 legitimate JS_* call sites across 102 files plus four
# upstream files with pre-existing `#pragma ... diagnostic` lines. A guard that treats the new
# side of a rename as a brand-new file therefore sees THE ENTIRE CONTENTS OF EVERY MOVED FILE
# as added, goes red on the first legitimate file move, and gets bypassed. A guard that cries
# wolf is worse than no guard. Symmetrically, a guard that only ever looks at the NEW side lets
# a protected golden walk out of goldens/ unseen, and lets a test be disabled by renaming it to
# a name nothing collects.
#
# So every path in the change is normalised to a triple
#
#     <status> <path-on-disk-or-empty> <baseline-path-or-empty>
#
# by norm_change() below, parsing `R<score>\t<old>\t<new>` from --name-status. Content
# comparisons (suppression, deny-list, test units) resolve the baseline as $BASE:<OLD side>, so
# a pure rename has an identical baseline and contributes nothing. The protected-path check sees
# BOTH sides, so a golden renamed out is caught on its old path. And the test check asks whether
# the NEW NAME IS STILL COLLECTABLE by pytest/pytest-bdd (is_collectable_test), not merely
# whether it is still somewhere under tests/ — `s1.feature` -> `s1.feature.disabled` stays under
# tests/ and is collected by nothing.
#
# NAMED LIMITATION: A FILE SPLIT (and a rename git scores too low to detect) GETS NO BASELINE
#
# The credit above is given only where git itself reports R or C. Two real Phase-1/2 shapes fall
# outside that, and both will read as "newly added" and go RED. This is a deliberate,
# conservative choice - refusing to credit an unpaired A rather than guessing which old file it
# came from - but it is a limitation, not an accident, and the escape hatch is below.
#
#   SPLIT.  `OOJSEngine.m` -> `OOJSEngine.cpp` + `OOJSValues.cpp`, verbatim, no content change,
#           is reported by git as `R050 old new1` plus a bare `A new2`. The R half is credited;
#           the A half has no baseline, so every symbol that migrated into new2 reads as newly
#           added. Reproduced: a 92-line file with 2 JS_* sites split verbatim in two ->
#           rc=1, "deny-list: OOJSValues.cpp reintroduces deny-listed symbols (0 -> 1 hits)".
#           This is the same SHAPE as the false positive that made an earlier version of this
#           guard permanently red, triggered by a split rather than by a move.
#   LOW SIMILARITY.  A move whose port also rewrote most of the lines falls below git's -M50
#           threshold and is reported as D + A rather than R, with the same consequence.
#           Reproduced: a rename git scores R066 passes; a 70%-rewritten one fails.
#
# WHAT TO DO WHEN THIS FIRES (either is fine; the second is better practice anyway):
#
#   * pass an explicit base:  tools/guardrails.sh --base <ref before the move>, or set
#     $OO_GUARDRAILS_BASE; or
#   * SPLIT THE COMMIT: land the pure move/split first (no content change - git then scores it
#     as R/C and it passes), and the edits in a second commit against that new baseline. This is
#     what the migration should be doing regardless: a move mixed with a rewrite is unreviewable.
#
# Raising git's rename detection (`--find-renames=<n>`, `-C`) was considered and rejected: it
# helps the low-similarity case only by making the guard credit files that are NOT the same
# file, which is exactly the hole this check exists to close. Auto-crediting an unpaired A whose
# content is a subset of some same-commit R's old side was also considered; it is not obviously
# safe (an agent can satisfy "subset of an old file" by copying a deny-listed line out of any
# moved file in the same commit), so the conservative refusal stands and is documented instead.
#
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
# WHAT "ADDED LINES" MEANS HERE
#
# added_lines() is a MULTISET DIFFERENCE against the baseline blob, not a hunk parse: a line is
# "added" only if the baseline file did not already contain (that many copies of) it. That is
# deliberately stronger than `git diff --unified=0` for this job - it is immune to renames, to
# reindentation-free moves, and to git's pathspec-limited rename detection - and it needs no
# temporary-path translation, which matters because this repository is worked from MSYS bash on
# Windows where native git does not accept /tmp-style paths.
#
# WHAT COUNTS AS A LIVE TEST UNIT — AND THE HEURISTIC LIMITS OF THAT MODEL
#
# The "gutted test" rule reduces each .py test and .feature to the IDENTITIES of its LIVE units
# and refuses any unit that was live at the base and is not live now (py_units/feature_units
# below). "Live" means the body does something at run time. That model is a heuristic, and it is
# wrong in both directions if it is not stated carefully, so its edges are named here:
#
#   MATCHED AS WHOLE NAMES, NOT SUBSTRINGS. A runtime skip is `skip`, `skipTest`, `skip_test`,
#     `skip_module` or `xfail` - bare, or on pytest/unittest/self. A helper whose name merely
#     CONTAINS the word is ordinary code: `self.skip_intro()`, `self.skip_first_frame()`,
#     `self.unskip_all()`, `self.frame_skip_setup()`, `pytest.skip_if_slow()` are all LIVE.
#     Extracting setup lines into a helper called skip_intro() is a pure refactor; a guard that
#     reddens on it is a guard that gets bypassed. Selftest 3q/3r hold both directions.
#   @skipif IS LIVE. `@pytest.mark.skipif(cond, ...)`, `@unittest.skipIf`, `@unittest.skipUnless`
#     are CONDITIONAL PLATFORM GUARDS - they run and assert on the matching platform, and they
#     are the dominant idiom in this repository's GUI suite. They are counted as units at both
#     ends, so gutting one is caught. Only a literal-True condition (`skipif(True, ...)`) and the
#     unconditional `@skip`/`@xfail` spellings mean "disabled". Measured on the real tree after
#     this change: test_g1_exit_via_mouse.py 13 defs -> 13 units (9 before),
#     test_win32_declarations.py 7 -> 7 (5 before); whole python suite 46 defs -> 46 units,
#     0 unguarded. Selftest 3s.
#   AN UNCONDITIONAL EXIT AT THE TOP LEVEL ENDS THE SCAN. `return`, `sys.exit()`, `os._exit()`
#     and an unconditional skip make everything below them unreachable, so a retained assertion
#     underneath does not count. An exit AFTER real work, or under an `if`, is ordinary control
#     flow and stays live. Selftest 3t.
#   `if True:` IS TRANSPARENT TO THAT RULE, NOT JUST TO LIVENESS. The header decides nothing, so
#     the DIRECT children of an `if True:` block (nested arbitrarily deep in such blocks, and the
#     one-line `if True: return` form) are judged at top level for the exit rule. Otherwise a
#     ONE-LINE WRAPPER re-opens every neutering the exit rule closes - measured: `if True:` /
#     `return` above a retained assertion read LIVE. A statement under a REAL construct inside
#     the block (`if True:` / `for ...:` / `return`) is conditional and stays live. Selftest 3u.
#
# STILL HEURISTIC — these read LIVE and this check will not catch them:
#
#   * a body whose only statement is a side-effect-free call the model cannot evaluate, e.g.
#     `logging.info("ran")` or `print(...)`: a call is assumed to do something, because assuming
#     otherwise would condemn every test that delegates to a helper;
#   * `with pytest.raises(ValueError):` / `pass` - the context manager itself is an assertion in
#     pytest, but a body that never reaches the raising call asserts nothing;
#   * `monkeypatch`/mock rewiring that makes a retained assertion trivially true;
#   * a unit deleted from one file and re-added to another (the SPLIT limitation below).
#
# These are deliberate: each would require evaluating Python rather than reading it, and a
# false RED costs more here than a missed subtle neutering, which review still catches.
#
# ANTI-VACUITY: a check that scans nothing must FAIL, not pass
#
# Every check states a fact about the tree that must hold for it to be capable of firing, and
# fails if it does not:
#
#   goldens      EVERY configured protected prefix must exist as a tracked path, except those
#                explicitly listed in PROTECTED_PREFIXES_PENDING with a reason. Asserting that
#                *some* prefix exists is not enough: one prefix being populated would let an
#                any-of assertion pass while the other half of the protected list is already
#                vacuous, so each prefix is checked on its own.
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
#   2. only CODE paths are scanned (see CODE_RE) - .md, .txt, .json/.jsonl, .feature and the
#      bead database are never scanned at all, which is where essentially all of that prose
#      lives.
#
# For the residue - this file, its selftest, and tools/gen-stories.py, which emits the
# prohibition boilerplate into every story - the patterns below are written in bracket form
# ([-]Wno-, #[[:space:]]*pragma) so they do not match their own source text, and the three files
# are additionally listed in SCAN_EXEMPT with a reason. Both, because either one alone is a
# silent dependency: if a future edit breaks the bracket trick the exemption still holds, and if
# someone drops the exemption the bracket form still holds.
#
# WHICH FILES ARE "CODE", AND WHY THE LIST GREW
#
# Compiler flags do not live in .c files; they live in the build system, and the previous list
# (meson/Makefile/GNUmakefile/.mk) missed most of the places THIS repository actually builds
# from. Justified against `git ls-files`, not against imagination:
#
#   .yml/.yaml           15 tracked, including upstream/oolite/.github/workflows/build-all.yaml
#                        and test_builds.yaml, upstream/oolite/.travis.yml and
#                        installers/flatpak/space.oolite.Oolite.yaml - all of which set build
#                        flags. This is where a -Wno- would actually be added today.
#   meson.options        upstream/oolite/meson.options is the tree's real meson option file;
#                        only the legacy spelling meson_options.txt was matched, so the live one
#                        was unscanned.
#   .pbxproj             7 tracked Xcode projects under upstream/oolite/tools and
#                        upstream/oolite-tests; OTHER_CFLAGS lives there.
#   .ini                 tools/meson/ccache-clang.ini is a meson cross/native file (already in
#                        the list; kept and now documented).
#   CMakeLists.txt/.cmake, Makefile.am/Makefile.in/configure.ac/configure.in, .m4, .xcconfig
#                        none tracked today. They are listed because a C++ port plausibly adds
#                        one, they cost nothing while absent, and the alternative - noticing the
#                        gap after a suppression has already landed - is the failure mode this
#                        whole file exists to prevent.
#
# Does adding .yml/.yaml break the prose-safety argument? No, and the argument has to be re-made
# rather than assumed: safety comes from scanning only ADDED lines, so a workflow file that has
# always contained a flag is invisible, and it comes from .md/.txt/.json/.jsonl/.feature staying
# OUT of CODE_RE, which is where documentation about these rules lives. Verified against all 28
# tracked files of the newly added types: NONE contains a suppression hit, and exactly ONE
# carries a pre-existing DENY-LIST hit -
#
#     upstream/oolite/installers/flatpak/space.oolite.Oolite.yaml:93
#     (the mozillajs-linux static-lib URL, matched by the JS pattern)
#
# which is harmless and must not be read as "the extension was paid for with a pre-existing
# red": the deny-list check is PER-FILE and BASELINE-RELATIVE (hit COUNT at the base vs now), so
# that line is part of that file's baseline. Appending an unrelated comment to it is rc=0;
# adding a SECOND matching line is correctly refused as "1 -> 2 hits". Confirmed by running it
# both ways. The residual risk is a YAML *comment* that quotes the prohibition - that is what
# SCAN_EXEMPT is for, and it is a one-line, reasoned entry rather than a silent hole.
#
# DOES ANY OF THIS APPLY TO upstream/ ?
#
# Yes, for suppression, tests and the deny-list, and deliberately so: upstream/oolite is a git
# subtree of OUR fork and is the tree being migrated (CLAUDE.md, ADR-0017). It is where the
# migration's warnings, its tests and its JS_*/GNUstep symbols all live, so exempting it would
# exempt the entire project. Pre-existing upstream suppressions are not an obstacle because only
# added lines are scanned AND because a rename is compared against its old path, which is what
# makes that sentence true rather than merely hopeful. (tools/check-file-modes.sh excludes
# upstream/ for the opposite and equally deliberate reason: file modes there come from upstream,
# so they are not ours to fix.)
set -u
# PIPEFAIL IS ON DELIBERATELY, AND IT IS LOAD-BEARING (bead oo-mxgy).
#
# Without it, every pipeline in this file reports only its LAST command's status, so a git,
# awk or grep that dies mid-pipe is invisible and the guard reports OK on a change it never
# actually read. That is the vacuous green this guard exists to prevent, one level up.
#
# Turning it on is also a trap, which is why this comment is long. The idiom
# `producer | grep -q PATTERN` BREAKS under pipefail: grep -q exits the instant it matches,
# SIGPIPEs a still-writing producer, and pipefail propagates 141 - so a SUCCESSFUL match reads
# as a FAILURE. Bead oo-3uf8 lost tier-c.sh's entire --only/--skip validator to exactly this.
# Note it does NOT reproduce with a toy producer: a short printf fits in the 64KB pipe buffer
# and finishes before grep exits, so a minimal test is green and proves nothing.
#
# THEREFORE: no `| grep -q` anywhere in this file, and never `|| true` to paper over one -
# that swallows genuine failures too. Use a shell loop with `case`, a here-string, or capture
# the producer's output into a variable first. tools/test_guardrails_pipefail.py FAILS if the
# idiom reappears here while pipefail is set.
set -o pipefail

cd "$(dirname "$0")/.." || exit 1

DENY_LIST="tools/deny-list.txt"
APPROVALS="tools/rebless-approvals.txt"

# Paths whose content is Jon's alone to change (CLAUDE.md rule 1). A change touching any of
# these needs a line in tools/rebless-approvals.txt naming the path.
PROTECTED_PREFIXES="goldens/ tests/golden/scenarios/"

# Anti-vacuity exemption, one line per prefix, with the reason it is allowed to be empty.
# A prefix listed here is still PROTECTED; it is only excused from "must exist as a tracked
# path". Anything not listed must exist, or the protected-path list has rotted.
# Empty is the expected end state: every protected prefix is populated, so every one of them is
# subject to the existence check. Add a line here only to cover a prefix protected in advance.
PROTECTED_PREFIXES_PENDING="
"

# Extensions that are CODE for the purpose of the suppression and deny-list scans. Everything
# not listed here (.md, .txt, .json, .jsonl, .feature, .lock, ...) is prose or data and is not
# scanned for symbols: that is what keeps documentation about a rule from tripping the rule.
# See "WHICH FILES ARE CODE" in the header for why each build-system entry is here.
CODE_RE='\.(c|h|m|mm|cc|cpp|cxx|hpp|hh|inc|sh|py|build|ini|mk|make|cmake|m4|xcconfig|pbxproj|yml|yaml)$|(^|/)(Makefile|GNUmakefile|Makefile\.am|Makefile\.in|CMakeLists\.txt|configure\.ac|configure\.in|meson\.build|meson\.options|meson_options\.txt)$'

# Curated, and every entry carries its reason. A file is listed here only when its JOB is to
# contain the forbidden text.
SCAN_EXEMPT="
tools/guardrails.sh|the guard itself: this header quotes every construct it forbids
tools/guardrails-selftest|constructs the violations that prove the guard fires
tools/deny-list.txt|is the pattern list; every line is a deny-list hit by definition
tools/gen-stories.py|emits the verbatim prohibition block into every generated story
upstream/oolite/src/Core/Scripting/ooscript/JSEngine_spidermonkey.cpp|the SpiderMonkey backend of the ooscript façade (ADR-0002 step 2, seam 1.1): the ONE translation unit whose job is to include jsapi.h; deleted at Phase 1 item 5. The façade header beside it is NOT exempt.
tools/check-jsengine-facade.sh|the façade's acceptance: it greps the header for the engine names it must not contain
tools/tier-b-guardrails-proof.sh|plants the deny-listed symbol that proves tier-b's stage 0 fires
tools/refactor/js-stubs.sh|documents, in comments/usage text, the JS_* call-site patterns it mechanically rewrites onto the façade (bead oo-oio); it does not itself call any engine function
tools/refactor/js_stubs.py|implements the mechanical JS_*-to-façade rewrite bead oo-oio describes; the JS_* names are pattern text (regex/docstrings), never engine calls made by this file
tools/refactor/js-stubs-selftest.sh|acceptance test asserting js-stubs.sh removes JS_* call sites from its fixture; quotes the targeted names to check for their absence
tools/refactor/testdata/OOJSVector.pre-retarget.m|frozen pre-retarget fixture (restored from git history) used only to prove js-stubs.sh's rewrite (bead oo-oio); never built, never linked
tools/refactor/testdata/js-stubs-string-literal.m|regression fixture proving js-stubs.sh leaves JS_* tokens inside string literals untouched (bead oo-oio review round 2); never built, never linked
tools/refactor/testdata/js-stubs-comment-call.m|regression fixture proving js-stubs.sh leaves JS_* call-shaped mentions inside comments untouched (bead oo-oio review round 2); never built, never linked
"

fail=0
note() { printf 'guardrails: %s\n' "$*" >&2; }
bad()  { fail=1; note "$*"; }

if [ "${1:-}" = "--explain" ]; then awk 'NR>1 && /^#/ {print; next} NR>1 {exit}' "$0"; exit 0; fi

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

TMPD="${TMPDIR:-/tmp}/oo-guardrails-$$"
mkdir -p "$TMPD" || exit 2
trap 'rm -rf "$TMPD"' EXIT

# --- the change ---------------------------------------------------------------------------
# "<status>\t<path>" (and "<status>\t<old>\t<new>" for a rename), base vs worktree, plus
# untracked files as adds.
CHANGE=$(git diff --name-status --find-renames "$BASE" --)
UNTRACKED=$(git ls-files --others --exclude-standard)
while IFS= read -r u; do [ -n "$u" ] && CHANGE="$CHANGE
A	$u"; done <<EOF
$UNTRACKED
EOF

# US: an ASCII unit separator. Fields are joined with it rather than with a tab because bash
# `read` treats tab as IFS WHITESPACE and would silently collapse an empty field - which is
# exactly how "the baseline path is empty for an add" turns into "the disk path is the
# baseline", i.e. back into the rename bug this file exists to fix.
US=$'\037'

norm_change() {  # <status><US><path-on-disk-or-empty><US><baseline-path-or-empty>
  printf '%s\n' "$CHANGE" | awk -F'\t' -v US="$US" '
    NF>=2 {
      st=$1
      if ((st ~ /^R/ || st ~ /^C/) && NF>=3) { print st US $3 US $2; next }
      if (st ~ /^D/)                        { print st US ""  US $2; next }
      if (st ~ /^A/ || st ~ /^\?/)          { print st US $2  US "" ; next }
      print st US $2 US $2
    }'
}

disk_paths() {   # every path that exists on disk after the change (new side of a rename)
  norm_change | awk -F"$US" '$2 != "" { print $2 }' | grep -v '^$'
}

scan_targets() { # "<disk-path><US><baseline-path>" for everything with content to scan
  norm_change | awk -F"$US" '$2 != "" { print $2 FS $3 }'
}

all_paths() {    # BOTH sides of every rename, for path-shaped rules
  norm_change | awk -F"$US" '{ if ($2 != "") print $2; if ($3 != "" && $3 != $2) print $3 }' | grep -v '^$'
}

is_code() {         # is_code <path> - does this path's extension/name make it CODE to scan?
  # Deliberately NOT `printf ... | grep -qE "$CODE_RE"`: see the pipefail note in is_exempt.
  # grep reads one short line here so it would probably never fire, but the shape is the bug
  # and the shape is what a later reader copies. A single non-pipelined grep is immune.
  grep -qE "$CODE_RE" <<< "$1"
}

is_exempt() {       # is_exempt <path>
  # NO `producer | grep -q` HERE, DELIBERATELY (bead oo-mxgy). `grep -q` exits the instant it
  # matches, which SIGPIPEs a still-writing producer; under `set -o pipefail` the pipeline then
  # reports 141 and a SUCCESSFUL match reads as a FAILURE. Bead oo-3uf8 lost tier-c.sh's whole
  # --only/--skip validator to exactly that. The loop below cannot be broken by adding pipefail.
  local e
  while IFS= read -r e; do
    case "$e" in "$1|"*) return 0 ;; esac
  done <<< "$SCAN_EXEMPT"
  return 1
}

base_blob() {       # base_blob <baseline-path> -> writes $TMPD/base, rc 0 if it exists
  [ -n "${1:-}" ] || return 1
  git cat-file -e "$BASE:$1" 2>/dev/null || return 1
  git show "$BASE:$1" > "$TMPD/base" 2>/dev/null
}

added_lines() {     # added_lines <disk-path> <baseline-path-or-empty>
  # Lines the baseline did not already contain. See "WHAT ADDED LINES MEANS HERE" above.
  if base_blob "${2:-}"; then
    awk 'NR==FNR { c[$0]++; next } { if (c[$0] > 0) { c[$0]--; next } print }' "$TMPD/base" "$1" 2>/dev/null
  else
    cat -- "$1" 2>/dev/null
  fi
}

# =============================================================================================
# 1. goldens/ — no change without a recorded re-bless approval
#
# Approval is a line in tools/rebless-approvals.txt naming the exact path, because "Jon's weekly
# re-bless queue" has to leave a mark in the tree to be checkable at all. Three properties make
# that more than a rubber stamp:
#
#   * a change may not approve ITSELF: if the same change also edits the approvals file, the
#     approval is refused. Adding an approval is a separate, human, reviewed commit.
#   * an approval names one path, not a directory, so it cannot be widened by accident.
#   * an approval line must start in COLUMN ONE. awk 'NF{print $1}' strips leading whitespace,
#     so an indented line approved just as well as a flush-left one - which means a live
#     approval could hide inside what every reader takes for the file's indented example block.
#     An approval has to look like an approval.
#
# BOTH SIDES of a rename are checked. A golden renamed OUT of a protected path is a golden
# leaving Jon's custody, and is refused on its OLD path; only tests/golden/scenarios/ was
# accidentally covered before, by also matching is_test_path(), and goldens/ had no such
# backstop at all.
# =============================================================================================
is_protected() {   # is_protected <path>
  local p
  [ -n "${1:-}" ] || return 1
  for p in $PROTECTED_PREFIXES; do
    case "$1" in "$p"*) return 0 ;; esac
  done
  return 1
}

is_pending_prefix() {
  # Array/loop rather than `| grep -q` — see is_exempt for why (bead oo-mxgy).
  local e
  while IFS= read -r e; do
    case "$e" in "$1|"*) return 0 ;; esac
  done <<< "$PROTECTED_PREFIXES_PENDING"
  return 1
}

approval_on_record() {  # approval_on_record <path>
  [ -f "$APPROVALS" ] || return 1
  # The approval file is read ONCE into a variable and matched by the shell. The old form
  # (`grep -v ... | grep ... | awk ... | grep -qxF`) had the pipefail trap at its tail: under
  # `set -o pipefail` the -q would SIGPIPE the awk/grep ahead of it and a found approval would
  # be reported as rc=141, i.e. NOT approved. See bead oo-mxgy.
  local line first
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case "$line" in
      ''|'#'*) continue ;;          # blank, or a comment in column 0
      [[:space:]]*) continue ;;     # indented: a continuation/comment, never an approval
    esac
    first=${line%%[[:space:]]*}
    [ "$first" = "$1" ] && return 0
  done < "$APPROVALS"
  return 1
}

check_goldens() {
  local p n live=0
  for p in $PROTECTED_PREFIXES; do
    n=$(git ls-files -- "$p" | grep -c .)
    if [ "$n" -gt 0 ]; then
      live=$((live + 1))
      is_pending_prefix "$p" && note "goldens: $p is populated ($n files) but is still listed in PROTECTED_PREFIXES_PENDING - that exemption is stale and should be deleted"
    elif is_pending_prefix "$p"; then
      note "goldens: $p is empty in this tree, exempted by PROTECTED_PREFIXES_PENDING (still protected)"
    else
      bad "goldens: protected prefix $p matches 0 tracked files - the protected-path list has rotted (add it to PROTECTED_PREFIXES_PENDING with a reason, or fix the prefix)"
    fi
  done
  [ "$live" -gt 0 ] || { bad "goldens: every protected prefix ($PROTECTED_PREFIXES) is empty - the protected-path list has rotted and this check cannot fire"; return; }

  # A change may not approve itself. This used to read `all_paths | grep -qx "$APPROVALS"`,
  # which is the single most dangerous instance of the trap this file now sets pipefail against:
  # all_paths is an awk pipeline over the whole change, grep -q exits on the FIRST match and
  # SIGPIPEs it, and under pipefail the pipeline returns 141 - so `&& self_approved=1` would
  # never fire and a self-approving change would sail through the guard. Loop, no pipe.
  local self_approved=0 ap
  while IFS= read -r ap; do
    [ "$ap" = "$APPROVALS" ] && { self_approved=1; break; }
  done < <(all_paths)

  demand() {  # demand <protected-path> <what happened>
    if [ "$self_approved" = 1 ]; then
      bad "goldens: $1 $2 by a change that also edits $APPROVALS - a change may not approve itself"
    elif approval_on_record "$1"; then
      note "goldens: $1 $2, re-bless approval on record - allowed"
    else
      bad "goldens: $1 $2 and has no re-bless approval in $APPROVALS (CLAUDE.md rule 1: re-blessing a golden is Jon's decision alone)"
    fi
  }

  local st disk base
  while IFS="$US" read -r st disk base; do
    [ -n "${st:-}" ] || continue
    case "$st" in
      R*|C*)
        if is_protected "$base" && ! is_protected "$disk"; then
          demand "$base" "is RENAMED OUT of a protected golden path to $disk"
        elif is_protected "$base" && is_protected "$disk"; then
          demand "$base" "is renamed to $disk inside a protected golden path"
        elif is_protected "$disk"; then
          demand "$disk" "is renamed into a protected golden path from $base"
        fi
        ;;
      D*)
        is_protected "$base" && demand "$base" "is deleted from a protected golden path"
        ;;
      *)
        p="$disk"; [ -n "$p" ] || p="$base"
        is_protected "$p" && demand "$p" "is under a protected golden path and is changed"
        ;;
    esac
  done <<EOF
$(norm_change)
EOF
}

# =============================================================================================
# 2. warning suppression — no NEW -Wno-*, #pragma/_Pragma diagnostic or unused-attribute
#
# _Pragma("GCC diagnostic ...") is matched as well as #pragma, because _Pragma is the ONLY way
# to put a diagnostic suppression inside a macro and is therefore the natural spelling in a
# port: `#define QUIET_BEGIN _Pragma("GCC diagnostic push") ...`. The same gap existed in the
# deny-list copy of these patterns, so neither of the two checks that tools/deny-list.txt
# claims "ask different questions" caught it; both are fixed.
# =============================================================================================
sup_patterns() {
  # Bracket forms so these lines do not match themselves; see the header.
  printf '%s\n' \
    '[-]Wno-[A-Za-z0-9=_-]+' \
    '#[[:space:]]*pragma[[:space:]]+(GCC|clang)[[:space:]]+diagnostic' \
    '[_]Pragma[[:space:]]*\([[:space:]]*"[^"]*diagnostic' \
    '__attribute__[[:space:]]*\(\([^)]*unused' \
    '__unused\b' \
    '[-]Wno-error'
}

sup_match() { grep -E -n "$(sup_patterns | paste -sd'|' -)" ; }

check_suppression() {
  # Anti-vacuity: the matcher must fire on its own canaries, built by concatenation so the
  # literals never appear in this file.
  local canary1 canary2 canary3 canary4
  canary1="cflags = ['-W""no-unused-variable']"
  canary2="#pragma clang diag""nostic ignored \"-W""shadow\""
  canary3="static int x __attr""ibute__((unused));"
  canary4="#define QUIET_BEGIN _Prag""ma(\"GCC diag""nostic push\")"
  local n
  n=$(printf '%s\n%s\n%s\n%s\n' "$canary1" "$canary2" "$canary3" "$canary4" | sup_match | wc -l)
  [ "$n" -eq 4 ] || { bad "suppression: matcher recognised $n/4 canary lines - the pattern set is broken and this check cannot fire"; return; }

  local p base out
  while IFS="$US" read -r p base; do
    [ -n "${p:-}" ] || continue
    is_code "$p" || continue
    is_exempt "$p" && continue
    [ -n "${base:-}" ] && is_exempt "$base" && continue
    [ -e "$p" ] || continue
    out=$(added_lines "$p" "${base:-}" | sup_match)
    if [ -n "$out" ]; then
      bad "suppression: $p adds a warning suppression (CLAUDE.md rule 3: never silence a warning):"
      printf '%s\n' "$out" | sed 's/^/    /' >&2
    fi
  done <<EOF
$(scan_targets)
EOF
}

# =============================================================================================
# 3. tests — never deleted, renamed out of the COLLECTED set, or gutted
#
# Two classifiers, and the difference between them is the point:
#
#   is_test_path()        "is this file part of the test corpus" - used for deletions, where
#                         anything under tests/ going away is suspicious.
#   is_collectable_test() "will a runner actually execute this" - test_*.py / *_test.py /
#                         *.feature / conftest.py / steps/*.py. Used for renames, because
#                         `s1.feature -> s1.feature.disabled` and
#                         `steps/world_steps.py -> steps/world_steps_disabled.py.bak` both stay
#                         under tests/ while pytest and pytest-bdd collect neither. Asking only
#                         "is the new path still under tests/" makes in-place disabling free.
#
# GUTTING is measured as a SET of live test units, not as a count. A count is trivially padded:
# replace an `assert True` step body with `pass` and the decorator is still counted; wrap a body
# in `if False:` and append a `return` and the count goes UP; tag the real scenario @skip and
# append a padding scenario and the count goes UP while the suite is disabled. So each .py test
# and .feature is reduced to the identities of its LIVE units - a step/def whose body is more
# than pass/return/.../docstring/comment and is not inside `if False:` and is not @skip-decorated;
# a scenario that is not @skip/@wip/@disabled-tagged, and its steps - and a unit that was live at
# the base and is not live now is a failure, however many new ones appeared. Adding tests is
# still free; renaming a live unit reads as removing it, which is correct under rule 2.
#
# ADR-0018 §5: .feature files and the component STEP LIBRARY are tests for this purpose. A step
# deleted from steps/ silently kills every scenario that used it, so the step library is
# classified as a test file in its own right.
# =============================================================================================
# NOTE ON "${1##*/}" RATHER THAN "$(basename -- "$1")". These two classifiers are semantically
# identical either way -- ${1##*/} strips everything through the last '/', which is what basename
# does for the relative, slash-separated, non-trailing-slash paths `git ls-files` emits -- but
# basename is an EXTERNAL COMMAND in a COMMAND SUBSTITUTION, i.e. a fork per call. check_tests()
# calls is_test_path() once for every tracked file to compute its anti-vacuity count, so on this
# repo's 1,999 tracked files that was 1,999 forks, and on Windows/MSYS2 a fork costs ~45 ms of
# kernel time rather than the ~1 ms it costs on Linux. MEASURED in this worktree: the classifier
# loop alone took 126 s with basename and 1 s with ${1##*/}, selecting the IDENTICAL set of 271
# files both ways (verified by diffing the two outputs). That single substitution is what takes
# `bash tools/guardrails.sh` from ~86-137 s to ~4 s -- see the cost note in tools/tier-b.sh.
# This is a pure speedup: no path is exempted, no scan is narrowed, and nothing is scoped down.
is_test_path() {   # is_test_path <path> : part of the test corpus
  case "$1" in
    tests/*|*/tests/*) return 0 ;;
  esac
  case "${1##*/}" in
    test_*.py|*_test.py|test_*.c|test_*.m|*.feature|conftest.py) return 0 ;;
  esac
  return 1
}

is_collectable_test() {  # is_collectable_test <path> : a runner will actually execute it
  case "$1" in
    */steps/*.py|steps/*.py) return 0 ;;   # pytest-bdd step library (ADR-0018 §5)
  esac
  case "${1##*/}" in
    test_*.py|*_test.py|*.feature|conftest.py|test_*.c|test_*.m|test_*.mm|test_*.cpp) return 0 ;;
  esac
  return 1
}

SKIP_TAG_RE='@(skip|wip|disabled|ignore|xfail|manual|todo)'

feature_units() {  # content on stdin -> one line per LIVE scenario and live step
  awk -v SK="$SKIP_TAG_RE" '
    function strip(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    BEGIN{ tags=""; featdead=0; cur=""; curlive=0 }
    {
      l=strip($0)
      if (l ~ /^@/) { tags = tags " " tolower(l); next }
      if (l ~ /^Feature:/) { if (tags ~ SK) featdead=1; tags=""; next }
      if (l ~ /^(Scenario Outline|Scenario Template|Scenario|Example|Examples|Background):/) {
        dead = (featdead || tags ~ SK); tags=""
        if (l ~ /^Examples:/) next
        if (l ~ /^Background:/) { cur="Background"; curlive=(dead?0:1); if (curlive) print "background"; next }
        sub(/^[A-Za-z ]+:[ \t]*/,"",l)
        cur=l; curlive=(dead?0:1)
        if (curlive) print "scenario:" cur
        next
      }
      if (l ~ /^(Given|When|Then|And|But|\*)([ \t]|$)/) { if (curlive) print "step:" cur "|" l; next }
    }'
}

py_units() {       # content on stdin -> one line per LIVE test/step unit
  awk -v SK="$SKIP_TAG_RE" '
    function strip(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    function indent(s,  m){ m=match(s,/[^ \t]/); return (m==0? -1 : m-1) }

    # An unconditional runtime skip. Reaching one at the top level of the body means every
    # statement after it is unreachable, so the unit asserts nothing at run time.
    #
    # THE METHOD NAME IS MATCHED WHOLE, NEVER AS A SUBSTRING. An earlier version matched any
    # callee "containing skip" and so condemned `self.skip_intro()`, `self.skip_first_frame()`,
    # `self.unskip_all()`, `self.frame_skip_setup()` and `pytest.skip_if_slow()` - ordinary
    # helpers whose names merely start or end with the word. Extracting two setup lines into a
    # helper called skip_intro() is a pure refactor that deletes no assertion, and a guard that
    # goes red on it is a guard that gets bypassed. Only the real spellings count:
    #   skip  skipTest  skip_test  skip_module  xfail        (bare, or on pytest/unittest/self)
    function isskip(st) {
      if (st ~ /^raise[ \t]+(unittest\.)?SkipTest([ \t]*\(|[ \t]*$)/) return 1
      if (st ~ /^(pytest|unittest|self)\.(skip|skipTest|skip_test|skip_module|xfail)[ \t]*\(/) return 1
      if (st ~ /^(skip|skipTest|skip_test|skip_module|xfail)[ \t]*\(/) return 1
      return 0
    }

    # An UNCONDITIONAL EXIT from the body. Everything below one at the top level of a body is
    # unreachable, so the scan must STOP there rather than skip the line and keep reading: a
    # `return` followed by the retained assertion is the exact structural twin of
    # `pytest.skip()` followed by the retained assertion, and is a one-line neutering.
    function isexit(st) {
      if (isskip(st)) return 1
      if (st ~ /^return([ \t]|$)/) return 1
      if (st ~ /^(sys\.exit|os\._exit|exit|quit)[ \t]*\(/) return 1
      return 0
    }

    # Do the DECORATORS of this def disable it outright? decs arrives already lowercased.
    #
    # @skipif / @skipIf / @skipUnless are CONDITIONAL PLATFORM GUARDS, not disabled tests: they
    # run, and assert, on the matching platform, and they are the dominant idiom in the real
    # suite here (18 of them across the GUI tests). Treating them as dead made those units
    # INVISIBLE AT BOTH ENDS of the comparison, so an agent could gut one to `pass` and this
    # check would say nothing. They are live; only a literal-True condition is unconditional.
    function decdead(decs) {
      if (decs ~ /@([a-z_][a-z0-9_.]*\.)?skip(if|unless)[ \t]*\([ \t]*(true|1)[ \t]*[,)]/) return 1
      if (decs ~ /@([a-z_][a-z0-9_.]*\.)?(skip|skiptest|xfail|wip|disabled|ignore|manual|todo)([ \t(]|$)/) return 1
      return 0
    }

    # A statement that executes nothing. useh=1 also treats a bare call to a helper defined
    # in THIS file whose own body is dead as dead - see "A HELPER EMPTIED IN THE SAME CHANGE".
    function stmtdead(st, useh,   nm) {
      if (st=="pass" || st=="...") return 1
      if (st ~ /^return([ \t]+None)?$/) return 1
      if (st ~ /^raise[ \t]+NotImplementedError/) return 1
      if (st ~ /^assert[ \t]+True[ \t]*$/) return 1
      if (isskip(st)) return 1
      if (useh && st ~ /^[A-Za-z_][A-Za-z0-9_.]*[ \t]*\(.*\)[ \t]*$/) {
        nm=st; sub(/[ \t]*\(.*$/,"",nm); sub(/^.*\./,"",nm)
        if (nm in DEADDEF) return 1
      }
      return 0
    }

    # Is the body of the def at line i (header indent ind) live? useh as above.
    #
    # TRANSPARENT-BLOCK BOOKKEEPING. `if True:` decides nothing, so its DIRECT children are at
    # the top level of the unit as far as unconditional exits go: `if True:` / `return` makes
    # everything below it unreachable exactly as a bare `return` does. TH/TB/TT are a stack of
    # open transparent blocks - header indent, direct-child indent (-1 until the first child
    # fixes it), and whether the header itself sat at a top-level position. Only DIRECT children
    # of a fully top-level chain count: a `return` nested inside a `for` inside `if True:` is
    # conditional, and calling it an exit would be a FALSE RED.
    function bodylive(i, ind, useh,   k,t,st,ti,skipind,indoc,bodyind,rest,body,live,TH,TB,TT,tdep,istop) {
      live=0; skipind=-1; indoc=0; bodyind=-1; tdep=0; k=i+1
      while (k<=NR) {
        t=L[k]; st=strip(t)
        if (st=="") { k++; continue }
        ti=indent(t)
        if (ti<=ind) break
        if (indoc) { if (index(st,td)>0 || index(st,tq)>0) indoc=0; k++; continue }
        if (skipind>=0) { if (ti>skipind) { k++; continue } ; skipind=-1 }
        if (substr(st,1,1)=="#") { k++; continue }
        if (index(st,td)==1 || index(st,tq)==1) {
          body=substr(st,4)
          if (!(length(st)>=6 && (index(body,td)>0 || index(body,tq)>0))) indoc=1
          k++; continue
        }
        if (bodyind<0) bodyind=ti
        # Leave any transparent block this statement has dedented out of.
        while (tdep>0 && ti<=TH[tdep]) tdep--
        # Is this statement at a TOP-LEVEL position, i.e. does reaching it guarantee that
        # everything textually below it in the unit is reachable only through it?
        if (tdep==0) istop = (ti<=bodyind)
        else {
          if (TB[tdep]<0) TB[tdep]=ti          # first direct child fixes the body indent
          istop = (TT[tdep] && ti<=TB[tdep])
        }
        if (st ~ /^if[ \t]+(False|0)[ \t]*:/ || st ~ /^if[ \t]+not[ \t]+True[ \t]*:/) { skipind=ti; k++; continue }
        # `if True:` is a TRANSPARENT block, not a live statement: the header decides nothing,
        # so the body is scanned at face value and an empty one stays dead. It is transparent to
        # UNCONDITIONAL EXITS too - `if True:` / `return` kills the rest of the unit exactly as a
        # bare `return` does, and that one-line wrapper would otherwise re-open every neutering
        # the exit rule closes - so the block is pushed on the transparent stack and its direct
        # children are judged at top level (see the function header).
        if (st ~ /^if[ \t]+(True|1)[ \t]*:/) {
          rest=st; sub(/^if[ \t]+(True|1)[ \t]*:[ \t]*/,"",rest)
          if (rest != "") {                    # one-liner: the whole block is this statement
            if (isexit(rest) && istop) return live
            if (!stmtdead(rest, useh)) live=1
            k++; continue
          }
          tdep++; TH[tdep]=ti; TB[tdep]=-1; TT[tdep]=istop
          k++; continue
        }
        if (substr(st,1,1)=="@") { k++; continue }
        # UNCONDITIONAL EXIT at the TOP LEVEL of the body: the scan stops. Nothing below runs, so
        # whether the unit is live was decided entirely by what came before.
        if (isexit(st) && istop) return live
        if (stmtdead(st, useh)) { k++; continue }
        live=1; k++
      }
      return live
    }

    { L[NR]=$0 }
    END{
      sq=sprintf("%c",39); tq=sq sq sq; dq=sprintf("%c",34); td=dq dq dq

      # Pass 1: every def in the file, helper-blind, so a helper gutted in the same change is
      # known to be dead before any unit that calls it is judged.
      for (i=1;i<=NR;i++) {
        s=strip(L[i])
        if (s !~ /^def[ \t]+/) continue
        nm=s; sub(/^def[ \t]+/,"",nm); sub(/[ \t]*\(.*$/,"",nm)
        if (!bodylive(i, indent(L[i]), 0)) DEADDEF[nm]=1
      }

      # Pass 2: the units themselves, helper-aware.
      for (i=1;i<=NR;i++) {
        s=strip(L[i])
        if (s !~ /^def[ \t]+/) continue
        ind=indent(L[i])
        decs=""; j=i-1
        while (j>=1) {
          t=strip(L[j])
          if (t=="") { j--; continue }
          if (substr(t,1,1)=="@") { decs = tolower(t) " " decs; j--; continue }
          break
        }
        nm=s; sub(/^def[ \t]+/,"",nm); sub(/[ \t]*\(.*$/,"",nm)
        id=""
        if (decs ~ /@(given|when|then|step|scenario)[ \t]*\(/) {
          kind="step"
          if (decs ~ /@given/) kind="given"
          else if (decs ~ /@when/) kind="when"
          else if (decs ~ /@then/) kind="then"
          else if (decs ~ /@scenario/) kind="scenario"
          q=""
          if (match(decs, dq "[^" dq "]*" dq)) q=substr(decs,RSTART+1,RLENGTH-2)
          else if (match(decs, sq "[^" sq "]*" sq)) q=substr(decs,RSTART+1,RLENGTH-2)
          id = kind ":" (q==""? nm : q)
        } else if (nm ~ /^test_/) {
          id = "def:" nm
        }
        if (id=="") continue
        if (decdead(decs)) continue
        if (bodylive(i, ind, 1)) print id
      }
    }'
}

unit_ids() {       # unit_ids <path> ; content on stdin -> sorted unique live-unit identities
  case "$1" in
    *.feature) feature_units | LC_ALL=C sort -u ;;
    *.py)      py_units      | LC_ALL=C sort -u ;;
    *)         : ;;
  esac
}

unit_weight() {    # unit_weight <path> ; content on stdin -> an integer
  local content; content=$(cat)
  local n=0
  case "$1" in
    *.c|*.m|*.mm|*.cpp|*.cc)
      n=$(printf '%s\n' "$content" | grep -cE '\b(assert|EXPECT_|ASSERT_|CHECK_)') ;;
    *)
      n=$(printf '%s\n' "$content" | grep -cE '[^[:space:]]') ;;
  esac
  printf '%s' "${n:-0}"
}

# compare_units <label> <baseline-path> <disk-path>
compare_units() {
  local label="$1" oldp="$2" newp="$3"
  local ids_b ids_n missing
  ids_b=$(git show "$BASE:$oldp" 2>/dev/null | unit_ids "$newp")
  ids_n=$(cat -- "$newp" 2>/dev/null | unit_ids "$newp")
  if [ -n "$ids_b" ]; then
    missing=$(printf '%s\n' "$ids_b" | LC_ALL=C comm -23 - <(printf '%s\n' "$ids_n"))
    if [ -n "$missing" ]; then
      bad "tests: $label is emptied - these live test units existed at $BASE_SHA and do not now (CLAUDE.md rule 2: never modify a test to make it pass):"
      printf '%s\n' "$missing" | sed 's/^/    - /' >&2
    fi
    return
  fi
  # No recognisable unit structure at the base (a helper, a C test, an odd file): fall back to
  # a weight that still catches wholesale emptying.
  local before after
  before=$(git show "$BASE:$oldp" 2>/dev/null | unit_weight "$newp")
  after=$(cat -- "$newp" 2>/dev/null | unit_weight "$newp")
  if [ "${after:-0}" -lt "${before:-0}" ]; then
    bad "tests: $label is emptied - test weight $before -> $after (CLAUDE.md rule 2: never modify a test to make it pass)"
  fi
}

check_tests() {
  local tracked
  tracked=$(git ls-files | while IFS= read -r f; do is_test_path "$f" && printf '%s\n' "$f"; done | wc -l)
  [ "$tracked" -gt 0 ] || { bad "tests: the test-file classifier matches 0 tracked files - it has rotted and this check cannot fire"; return; }
  note "tests: classifier matches $tracked tracked test files"

  local st disk base
  while IFS="$US" read -r st disk base; do
    [ -n "${st:-}" ] || continue
    case "$st" in
      D*)
        is_test_path "$base" && bad "tests: $base is deleted (CLAUDE.md rule 2: never modify or delete a test)"
        ;;
      R*|C*)
        if is_collectable_test "$base" && ! is_collectable_test "$disk"; then
          bad "tests: $base is renamed to $disk, out of the test set - nothing collects the new name, so that removes a test (CLAUDE.md rule 2)"
        elif is_collectable_test "$base"; then
          compare_units "$base -> $disk" "$base" "$disk"
        fi
        ;;
      M*|T*)
        is_test_path "$disk" || continue
        compare_units "$disk" "$base" "$disk"
        ;;
    esac
  done <<EOF
$(norm_change)
EOF
}

# =============================================================================================
# 4. deny-list — no NEW hit in a changed source file (CLAUDE.md rule 8)
#
# Per-file and baseline-relative, exactly as tools/tier-a.sh does it, so that the 3,828 call
# sites that legitimately exist today do not fail every run: what fails is a file growing a hit
# it did not have at the base. For a RENAME the base is the OLD path, so moving a file that
# already contained 3 JS_* calls is a 3 -> 3 no-op rather than a 0 -> 3 regression.
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

  local p base now before
  while IFS="$US" read -r p base; do
    [ -n "${p:-}" ] || continue
    is_code "$p" || continue
    is_exempt "$p" && continue
    [ -n "${base:-}" ] && is_exempt "$base" && continue
    [ -e "$p" ] || continue
    now=$(cat -- "$p" | deny_count)
    if [ -n "${base:-}" ] && git cat-file -e "$BASE:$base" 2>/dev/null; then
      before=$(git show "$BASE:$base" | deny_count)
    else
      before=0
    fi
    if [ "${now:-0}" -gt "${before:-0}" ]; then
      bad "deny-list: $p reintroduces deny-listed symbols (${before} -> ${now} hits at $BASE_SHA):"
      while IFS= read -r pattern; do
        case "$pattern" in ''|'#'*) continue ;; esac
        grep -nE "$pattern" -- "$p" | sed 's/^/    /' >&2
      done < "$DENY_LIST"
    fi
  done <<EOF
$(scan_targets)
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
