# ADR-0036 — An out-of-range `quantity_unit` is `UNITS_UNKNOWN`

**Status:** Proposed — default in effect (Claude Code, frontier agent, beads oo-8j9q and oo-cpv4,
2026-09-23; ADR-0013, CLAUDE.md rule 10). Jon may override.
**Date:** 2026-09-23

## Context

`-massUnitForGood:` in `OOCommodities.mm` and `OOCommodityMarket.mm` read a good's
`quantity_unit` from `trade-goods.plist` and cast it straight to `OOMassUnit`
(`UNITS_TONS`/`UNITS_KILOGRAMS`/`UNITS_GRAMS`, 0-2). The value is never checked: the validation in
`-[OOCommodities init]` is a commented-out TODO, so any unsigned number an expansion writes reaches
the cast. After the extractor sweep rewrote those reads to `oo::PListView(...).get<unsigned int>`,
clang-tidy's `clang-analyzer-optin.core.EnumCastOutOfRange` could see the value
(`OOUnsignedIntFromObject` clamps to `UINT_MAX`) and flagged both casts. Rule 3 rules out a
suppression. Giving the enum a fixed `unsigned int` type makes every value defined but does not
satisfy the checker (checked with clang-tidy 22.1.8).

Today a value of 3 or more is formally undefined (an enum without a fixed type cannot hold it).
In practice it shows as "??" (`DisplayStringForMassUnit`'s fall-through), is treated as tons by
`-[Universe describeCommodity:amount:]`'s `default:`, logs a warning and gives an amount of 1 in
`-getRandomAmountOfCommodity:`, never equals any unit in comparisons, and
`marketSorterByMassUnit` sorts by the raw number.

## Decision

1. `OOMassUnit` gets a fourth enumerator, `UNITS_UNKNOWN` (= 3), for "none of the units".
2. `OOMassUnitFromNumber(unsigned n)` (`OOCommodities.h`) returns `(OOMassUnit)n` for `n <= 2` and
   `UNITS_UNKNOWN` otherwise. Both `-massUnitForGood:` methods use it instead of the cast.
3. The two switches without a `default:` list `UNITS_UNKNOWN` explicitly and leave the switch as
   3+ did before, so they stay complete under `-Wswitch`: `DisplayStringForMassUnit` falls through
   to "??", and `-[Universe getRandomAmountOfCommodity:]` to its "unrecognised mass unit" warning
   and an amount of 1. The two switches in `-[Universe describeCommodity:amount:]` already have a
   `default:` (tons), which `UNITS_UNKNOWN` takes, as 3+ did before.

## Consequences

- Behaviour for 0-2, which is every unit in the shipped data, is unchanged, and so are the goldens.
- A value of 3 or more still displays as "??", still reads as tons in commodity descriptions, still
  logs the unrecognised-unit warning with an amount of 1, and still equals no real unit.
  **The only visible change:** goods whose `quantity_unit` is 3 or more now sort together in the market's mass-unit sort (all as 3), where before they sorted by their
  raw number. That affects only invalid data, which was undefined behaviour before.
- The analyzer finding is fixed, not silenced: the enum is only ever given one of its own values.

## Alternatives

- **Justified NOLINT on the two casts** (precedent: `OOJavaScriptEngine.mm`). No behaviour change
  at all, but it is a suppression (rule 3) and keeps the undefined behaviour.
- **Clamp to `UNITS_GRAMS` (2) or `UNITS_TONS` (0)** without a new enumerator. This changes what
  invalid data displays ("g"/"t" instead of "??"). Rejected: it is a larger visible change.
- **Validate `quantity_unit` at load** (the `-[OOCommodities init]` TODO, which would also map
  `t`/`kg`/`g`). This is the right long-term fix but a feature, not a conversion. It belongs in its
  own bead.

## History

- 2026-09-23: proposed with the default in effect (oo-8j9q, oo-cpv4).
