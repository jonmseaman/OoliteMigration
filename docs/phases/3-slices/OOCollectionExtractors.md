# Slice plan: OOCollectionExtractors

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-oucd). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOCollectionExtractors.md`.

- **Expected outcome: nothing to slice.** Phase 2 retires this file: bead oo-snzn (ADR-0043
  step 7, "retire, do not sweep") deletes `Core/OOCollectionExtractors.mm`/`.h`, since it is a set
  of categories on Foundation classes (`NSArray`/`NSDictionary (OOExtractor)`,
  `NSMutableArray`/`NSMutableDictionary`/`NSMutableSet (OOInserter)`) plus the `OO*FromObject`
  converters, all of which go with gnustep-base. The plan therefore says `retired-by: oo-snzn`,
  and the checker passes when the file is absent.
- **Fallback if it survives into Phase 3:** it no longer needs pre-splitting. It is 816 lines now
  (1,564 when the bead was generated), so the whole file is one slice (~710 own lines, ~1,160
  read). A category on a Foundation class has no C++ class to become a member of; per the recipe
  row `@interface NSString (OOFoo)` it becomes free functions in a namespace, and every caller
  changes with it: that is an interface change, so if this fallback is ever used the slice goes
  to a frontier agent, not the fleet.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 (fallback) | the whole file | ~710 | ~1,160 |

```slice-plan
source: upstream/oolite/src/Core/OOCollectionExtractors.mm
header: upstream/oolite/src/Core/OOCollectionExtractors.h
retired-by: oo-snzn

slice 1: the whole file, only if oo-snzn has not deleted it
  *
```
