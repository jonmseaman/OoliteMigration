# Feature Specification: ICU case mapping in `oofnd/String.hpp`

**Feature Branch**: `seriesb/032-cleanup` (in `oolite-dev`)
**Created**: 2026-11-15
**Status**: Implemented
**Input**: "Figure out what it would take to replace String.hpp with library code like ICU or
standard C++." Jon chose (2026-11-14) to move the Unicode tables to ICU where that is acceptable.
Where a swap isn't safe, the existing code stays.

## Decision (Jon, 2026-11-14)

`oo::str::toUpper`/`toLower` may follow ICU's simple case mapping instead of GNUstep 1.31.1's probed
table. GNUstep's table is an older subset of Unicode. Upstream on macOS already uses current tables, and
the game's callers case-map ASCII keys, extensions and names (the font draws only Latin-1/CP1252). The
tests that pinned GNUstep's full-BMP answer are edited under this decision. Each edit is listed in
[test-ledger.md](test-ledger.md). This is a signed-off exception to hard rule 1.

## Requirements

- **FR-001**: `toUpper(c)`/`toLower(c)` MUST return ICU's `u_toupper`/`u_tolower` of `c`, or `c` itself
  when ICU's answer is outside the BMP. They stay one-unit-to-one-unit.
- **FR-002**: On U+0000–U+017F (ASCII, Latin-1, Latin Extended-A) the answers MUST equal GNUstep's.
  A digest of GNUstep's answers on that range is pinned. Every ICU version agrees there.
- **FR-003**: No test may pin an answer that depends on the ICU version. CI uses Ubuntu 26.04, Fedora,
  Arch, macOS Homebrew, MSYS2 and Flatpak, each with its own ICU. BMP answers outside FR-002's range
  are checked against ICU at run time, not against a fixed digest.
- **FR-004**: A GNUstep-probed table is replaced by an ICU property only if ICU gives the same answer
  for every BMP unit, on every supported ICU version.
- **FR-005**: Behaviour-identical std rewrites (`hasPrefix`/`hasSuffix` on UTF-8 bytes,
  `compareVersions`, the strict UTF-8 decoder) MUST pass every existing test unedited.
- **FR-006**: Every test edit MUST be in the test-change ledger with its old and new form and the reason.

## Notes and decisions taken without Jon (rule 8)

- **Probe** (`.agent-tmp/icu-probe/probe.cpp`, ICU 78.3 / Unicode 17.0 on MSYS2):
  - Case: ICU upper-cases 493 BMP units differently from GNUstep and lower-cases 485 differently.
    Only one unit that GNUstep mapped maps elsewhere in ICU: U+03F2 GREEK LUNATE SIGMA upper-cases to
    U+03F9 (Unicode 4.0), not U+03A3. No answer falls outside the BMP.
  - Agreement range: U+0000–U+017F agree exactly. The first disagreement is U+0180, and some later ones
    are recent (U+019B → U+A7DC is Unicode 16), so ICU's answers vary by version. That is why FR-003
    exists.
  - Other tables:

    | Table | Units that differ from ICU |
    |---|---|
    | `extendsSequence` vs Mn/Mc/Me/Lm + low surrogates | 70 |
    | `CharacterSet::alphanumeric` vs L/M/N | 140 |
    | `whitespace()` / `isWhitespaceOrNewline` vs `u_isUWhiteSpace` | 1 (U+200B) |
    | `newline()` | 2 (U+2028/9) |
    | `decimalDigit` vs Nd | 0 on ICU 78 |
- **Kept, by FR-004.** `extendsSequence`, `alphanumeric`, the whitespace sets and `newline()` differ,
  so they stay. `decimalDigit` matches on ICU 78 but can't be shown to match on older ICU versions in CI.
  It is ten lines of table, so it stays too (the conservative default). The whitespace sets also drive
  PList and number parsing, which is one more reason not to change them.
- **Std cleanup (FR-005).**
  - `hasPrefix`/`hasSuffix` compare an ASCII prefix or suffix as bytes. The fallback stays UTF-16.
  - `decodeStrictUtf8` uses `u_strFromUTF8`.
  - Old and new header were fuzzed against each other on 2M random byte strings (including invalid
    UTF-8 and WTF-8), covering `hasPrefix`, `hasSuffix` and `decodeUnicodeFile`, with identical
    digests (`.agent-tmp/icu-probe/fuzz.cpp`).
  - `compareVersions` is unchanged. A `lexicographical_compare_three_way` form needs padded copies,
    which means more allocations for no gain.
- **Scanner.** `Scanner.hpp`'s case-insensitive matching now folds through ICU as well. Its tests
  (`namedSetsMatchGNUstepOverTheBMP`, `scriptCorpusMatchesGNUstep`) pass unedited.
- **Pre-existing component failure.** `test_t1_tutorial_walkthrough.py::test_every_lesson_is_reachable_and_the_basic_controls_respond`
  fails on this machine with the game dropping the debug-console connection (`ConnectionResetError`,
  nothing in Latest.log or stderr). The base `seriesb/032-cleanup` (`4f95b7724`), built in the same
  worktree, fails the same way, so it is not caused by this feature. It is not investigated here.
- **Out of scope.** These have no library equivalent with their semantics and stay as they are:
  `formatRuntime`/`FormatArg`, the GNUstep path functions, the number readers, `pointerDescription`,
  the `decodeUnicodeFile` BOM handling, the WTF-8 conversions in `PList.hpp`, and the `Scanner` state
  machine.
- **Not committed here.** This spec directory sits in the parent repo on `main`, which agents don't
  commit to (rule 3). It is left uncommitted for Jon.
