# ADR-0054: What the Foundation census counts, and at which stage

- Status: Proposed. The default is in effect until Jon decides (CLAUDE.md rule 10).
- Date: 2026-09-29
- Beads: oo-qps.20 (this ADR), oo-qps.27 (the tool change), gate oo-qps.3; owners oo-snzn,
  oo-qps.28, oo-qps.29; stragglers oo-qps.21..26

## Context

Gate oo-qps.3's acceptance is `bash tools/check-foundation-free.sh --stage sweeps` (oo-qps.1).
With every sweep, family, gap and bridge-deletion bead closed, it reported 398 findings in 501
files on phase-2 48afc5f71. Classified line by line (planner scratch, not committed):

| Class | Findings | What |
|---|---:|---|
| A. Stragglers and regressions | 184 | code the sweeps missed or a merge reverted: oo-qps.21..26 |
| B. Owned by a bead after the gate | 106 | OOCollectionExtractors.h/.mm 88 (oo-snzn), OOStringExpander.h/.mm 14 (ADR-0052), the OOLogOutputHandler NSLog-hook bridge 4 (3 `bridge` + 1 `ns`) |
| C. Mac-only code | 71 | `#if OOLITE_MAC_OS_X` / `#if OOLITE_USE_APPKIT_LOAD_SAVE` blocks in GameController.h/.mm, OOMusicController.mm, OOLogOutputHandler.mm, PlayerEntityLoadSave.mm, Universe.h/.mm, OOOXPVerifier.mm |
| D. Not identifiers | 37 | NS words in comments (26) and in string literals (11) |

(184 + 106 + 71 + 37 = 398. D's comment findings include three in the NSLog-hook bridge files.)

The tool's own header says it reports "every NS[A-Z]... identifier", that comment lines are ignored,
and that literals are never a finding. It implements "comment line" as a line that *starts* with
`//`, `/*` or `*`, so it counts a block-comment line that does not start with `*` (AI.mm 361,
OOPolygonSprite.mm "NSPoints"), a trailing `// ...` (ShipEntity.mm 14849), and it looks inside plain
`"..."` strings (`#import "NSObjectOOExtensions.h"` in six files, the "NSTimer ignoring exception"
log text that GameController.mm keeps byte-for-byte, the `"NSUnderlyingError"` key).

ADR-0043 item 18(b) already decided the Mac case: Mac-only Foundation code is "`OOLITE_MAC_OS_X`
code that the fleet never compiles; ... deferred to Phase 5 (the Mac port), fenced as they are, and
the grep skips the `#if OOLITE_MAC_OS_X` block". The census was written later and does not skip it.
On macOS that code links Apple's Foundation, not gnustep-base, so it is not what oo-qps removes.

Class B is on the wrong stage. The sweeps stage exists so the gate can pass while the boundary that
oo-qps's own children delete is still present (its BOUNDARY list). Three more things are in exactly
that position, each with a documented owner that runs after the gate:

- `OOCollectionExtractors.h/.mm`: oo-snzn retires it (ADR-0043 step 7). Its notes (2026-09-28)
  record that it now depends on oo-qps.16 and that oo-qps.3 no longer depends on it; oo-qps.17
  depends on it.
- `OOLogOutputHandler+FoundationBridge.h/.mm` and its `#import` in OOLogOutputHandler.h: the
  gnustep-base NSLog hook, "deleted with gnustep-base by oo-qps" (ADR-0043 item 18(a); oo-vors).
  No oo-qps child owned it; oo-qps.28 now does.
- `NSString *OOExpandDescriptionString(...)` / `NSString *OOGenerateSystemDescription(...)` in
  OOStringExpander.h/.mm: kept for the expander differential test until "the test's Foundation
  adapter" goes (ADR-0052 item 3). No bead owned it; oo-qps.29 now does.

## Decision (recommended default)

1. **Mac fence, both stages.** A line inside an active `#if`/`#elif` group whose condition is an
   enumerated fence macro — `OOLITE_MAC_OS_X` or `OOLITE_USE_APPKIT_LOAD_SAVE` (PlayerEntityLoadSave.h
   defines it as `OOLITE_MAC_OS_X && ...`) — alone or as an `&&` conjunct, or inside the `#else` of
   `#if !<fence macro>`, is not scanned for `ns` or `oolog` tokens. `#ifdef` (OOCocoa.h always
   defines the macro, to 0 or 1), `||` and negated conditions are not fences. Fenced lines are
   counted in an information-only "mac-fenced (Phase 5)" total, as `@"..."` literals are, so they
   stay visible. Adding a fence macro is an amendment to this ADR. The Phase 5 entry gate inherits
   the fenced code as it stands.
2. **Comments and literals, both stages.** Before the `ns` and `oolog` scans, the tool strips
   `/* ... */` (across lines), a trailing `// ...`, and the contents of `"..."`, `'...'` and
   `@"..."`. The Foundation-import and bridge-include checks keep reading the raw line. This is the
   tool's existing spec ("identifier", "comment lines", "literals are never a finding") implemented
   fully; code on a line with a trailing comment is still scanned.
3. **Post-gate owners, sweeps stage only.** `OOCollectionExtractors.h` and `.mm` join BOUNDARY; the
   NSLog-hook bridge files and their `#import` are exempt from `bridge` and `ns` findings; in
   OOStringExpander.h/.mm only the declaration/definition lines of the two ADR-0052 functions are
   exempt. The source stage (oo-qps.17's acceptance) keeps counting all three, so each fails the
   phase until its owner lands: oo-snzn, oo-qps.28 and oo-qps.29 each block oo-qps.17.
4. **The expander surface (oo-qps.29).** Recommended default: the two functions move under a
   test-only fence macro, `OO_EXPANDER_TEST_SURFACE`, that only `tools/check-string-expander.sh`
   defines, and the census treats it as a fence at the source stage. The test and its digests do not
   change (rule 2). Retiring or porting the test instead is a test modification and Jon's decision.
5. Every A-class finding is a bead that blocks oo-qps.3 (oo-qps.21..26), so the gate's acceptance
   does not change: `--stage sweeps` must report 0 after oo-qps.27 and those beads.

## Consequences

- Each change to what the census counts has a selftest case (oo-qps.27): the Mac block skipped;
  its `#else` counted; NS words in comments and strings not counted; code before a trailing comment
  counted; post-gate owners exempt at sweeps and failing at source.
- Mac-fenced code keeps Foundation/AppKit names after Phase 2. The deny-list (oo-qps.19) is
  per changed file and baseline-relative, so it does not fail on them; if oo-qps.19 enumerates
  Foundation names, it needs the same fence or a Phase 5 carve-out.
- Two regressions found by the classification (oo-3rb.276's merge reverted oo-xk5h in
  ShipEntityAI.mm; oo-3rb.264's merge reverted oo-3yh0 in OOCache.mm / OOPriorityQueue.mm) show that
  a stale bead branch merged with its own side of a conflict can undo closed work that no remaining
  check covers. The absolute census covers Foundation names only.
- `check-string-expander.sh` still needs gnustep-base installed. Once oo-qps.18 removes it from
  `tools/setup-windows.sh`, that harness needs either its own install step or a retirement decision.

## History

- 2026-09-29: proposed by the oo-qps.3 gate planner; default in effect.
