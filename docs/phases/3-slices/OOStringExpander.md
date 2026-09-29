# Slice plan: OOStringExpander

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-l1es). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOStringExpander.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/OOStringExpander.mm` (1,569 lines) + header (343 lines, mostly the expansion
  syntax documentation). **No class**: ~55 free functions, already on `std::string`/`oo::PList`
  after Phase 2. Objective-C is left only where they reach the game objects: `UNIVERSE`/`PLAYER`
  message sends, the `@selector` table for special keys, legacy selector lookup, system names and
  random digrams.
- **Shape:** one slice holding every function that still has Objective-C (~440 lines); the rest
  (the expander core, operators, percent escapes, syntax reporting) is plain C++ and stays
  verbatim. The `@selector` table and `LookUpLegacySelector` are the one real design point: they
  become an explicit key → member-function map (recipe row `NSSelectorFromString`).
- **Order:** one slice. It needs `Universe`/`PlayerEntity` members to call; until those are C++,
  the calls stay message sends through the bridge the Phase 3 recipe prescribes.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | every function with Objective-C (entry points, special keys, selectors, system names, digrams) | ~440 | ~1,005 |
| verbatim | expander core, operators, percent escapes, helpers | — | not read |

```slice-plan
source: upstream/oolite/src/Core/OOStringExpander.mm
header: upstream/oolite/src/Core/OOStringExpander.h

slice 1: functions that still message game objects or use @selector
  cxx_OOExpandDescriptionString()
  OOStringExpanderDefaultRandomSeed()
  ExpandStringKeySpecial()
  ExpandStringKeyKeyboardBinding()
  SpecialSubstitutionSelectors()
  ExpandStringKeyFromDescriptions()
  ExpandStringKeyMissionVariable()
  LookUpLegacySelector()
  ExpandSystemNameForGalaxyEscape()
  ExpandSystemNameEscape()
  GetSystemName()
  GetSystemDescriptions()
  OldRandomDigrams()
  NewRandomDigrams()

verbatim: plain C++ expander core and helpers, no Objective-C (checked)
  *
```
