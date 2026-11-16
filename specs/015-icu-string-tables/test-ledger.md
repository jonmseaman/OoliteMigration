# Test-change ledger: 015-icu-string-tables

These edits are allowed by Jon's decision of 2026-11-14 (see [spec.md](spec.md)) and by FR-006.
No test was deleted. Any edit not listed here is not covered by this decision.

| File | Test | Before | After | Why |
|---|---|---|---|---|
| `tests/unit/oofnd/test_string.cpp` | `caseTablesMatchGNUstepOverTheBMP` → `caseMappingIsIcusAndMatchesGNUstepOnLatin` | FNV digest `0x314D997D349929D1` of GNUstep's upper/lower answers for every non-surrogate BMP unit | (1) FNV digest `0x11F9C71353F9624F` of GNUstep's answers for U+0000–U+017F, captured from the GNUstep table before it was removed; (2) every BMP unit equals ICU's `u_toupper`/`u_tolower`, kept in the BMP | Case mapping now comes from ICU. ICU's answers outside U+0000–U+017F vary by version (FR-003), so they are compared with ICU at run time. GNUstep parity is still pinned where every ICU version agrees with it. |
| same | same | `toUpper(0x2C30) == 0x2C30` (Glagolitic unmapped) | `toUpper(0x2C30) == 0x2C00` | ICU maps Glagolitic (Unicode 4.1); GNUstep's table had no entry for it. All other assertions in the test are unchanged. |
| same | `stringCorpusMatchesGNUstep` → `stringCorpusMatchesGNUstepWithIcuCase` | digest `0x078ADF6EE40A0057` | digest `0xE9A5708421748AEB`, recomputed by a copy of the test's own corpus code (`.agent-tmp/icu-probe/corpus.cpp`), which gives the old value against the old header | The corpus pool includes U+1E9E (lower → U+00DF) and U+10D0 (upper → U+1C90), which ICU maps and GNUstep didn't. Pool units map the same in every ICU version since 11. |
| same | file header comment | "every expectation … captured from gnustep-base" | adds the case-mapping exception | Keeps the description true. |
