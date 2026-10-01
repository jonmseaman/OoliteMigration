# ADR-0053: DESC() gets std::string twins; callers move per file

- Status: Accepted (Jon, 2026-09-30, in chat). Recorded from the in-effect default (CLAUDE.md rule 10).
- Date: 2026-09-29
- Beads: oo-3rb.312 (DESC half of oo-mr9c), seam oo-3rb.316, chunks oo-3rb.317..323

## Context

`DESC(key)` / `DESC_PLURAL(key, n)` (Universe.h) expand to `OOLookUpDescriptionPRIV` /
`OOLookUpPluralDescriptionPRIV` in `Universe+FoundationBridge.h`: an `NSString` key in, an
`NSString` out, each exactly `oo::NSStringFrom(cxx_OOLookUp*PRIV(oo::StdString(key)))`. oo-mr9c
cannot delete that bridge while ~780 uses in 30 files need it. The macro cannot be flipped in
place, file by file: `DESC(@"k")` is an `NSString` literal key and `DESC("k")` a C string, so no
spelling of a use compiles against both macros, and a flip of every use at once is one ~1,500-error
change that fails the story checks (≤ 400 lines, ≤ 8 files).

## Decision (recommended default)

The precedent of `OOLog` -> `OO_LOG` (ADR-0043 item 17, ADR-0035):

1. A seam adds `OO_DESC(key)` / `OO_DESC_PLURAL(key, count)` to Universe.h beside the old
   macros: the same literal-only rule (`key ""`), expanding to `cxx_OOLookUpDescriptionPRIV` /
   `cxx_OOLookUpPluralDescriptionPRIV`, returning `std::string`.
2. Callers move per file in chunk beads, mechanically, at the use: `oo::StdString(DESC(@"k"))`
   and `oo::DescriptionOf(DESC(@"k"))` become `OO_DESC("k")`; `oo::OptionalString(DESC(@"k"))`
   becomes `OO_DESC("k")` where the consumer takes `std::optional<std::string>` (DESC never gave
   nil); any consumer still typed `NSString` gets `oo::NSStringFrom(OO_DESC("k"))`, the
   bridge's own conversion moved to the call.
3. oo-mr9c deletes `DESC` / `DESC_PLURAL` with the bridge. `OO_DESC` keeps its name (renaming
   ~780 uses back buys nothing).

## Consequences

- Text is unchanged: every use reaches the same `cxx_` lookup the bridge forwarded to.
- `oo::NSStringFrom(OO_DESC(...))` at unmigrated `NSString` boundaries is ordinary
  `OOStringBridge.h` use, removed with the rest by the oo-qps drop-bridge beads.
- Seven chunk beads instead of one flip; chunks touch disjoint files, so they land in any order
  after the seam.

## History

- 2026-09-29: proposed by the oo-3rb.312 worker (orchestrator default); default in effect.
