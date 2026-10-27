# Phase 5b — Data formats: JSON5 beside property lists

**Status:** PROPOSED — awaiting Jon's approval (nothing here is started; no beads exist) ·
**Est.:** 1–2 eng-months · **Depends on:** [Phase 4](4-remove-objc-runtime.md) ·
**Runs in parallel with:** [Phase 5](5-apple-silicon.md) (this work needs no Mac) ·
**Decision record:** [ADR-0065](../decisions/0065-json5-beside-plists.md) (proposed)

## Goal

Oolite's data files can be written in **JSON5** as well as in the property-list formats it reads
today, with **no expansion breaking**. Every plist-shaped file the game loads (`shipdata`,
`equipment`, `descriptions`, AI, scripts lists, `manifest`, …) may also be supplied as a `.json5`
file with the same name and the same data model; the game merges the two exactly as it merges two
plists today. A converter tool round-trips plist ↔ JSON5 losslessly, so modders can move at their
own pace and the core game can move its own `Resources/` when Jon chooses.

Why: property lists are a NeXT/Apple format. After Phase 4 the game reads them with its own C++
parser (`src/oofnd/PList*.hpp`) — there is no Objective-C or GNUstep behind them any more — so this
is **not** a dependency-removal phase. It is a modding-ergonomics phase: JSON5 is the closest modern
format to the OpenStep text plists modders already write (comments, unquoted keys, trailing commas),
and every editor, linter and language understands it.

## What stays (non-goals)

- **Plists are read forever.** Thousands of published OXPs/OXZs ship OpenStep and XML plists. Removing
  plist support would break the expansion ecosystem; it is never on the table in this phase.
- **Saved games stay XML plists** (`.oolite-save`, written by `OOWriteXMLPListToFile`). Old saves
  must load and new saves must load in old Oolite builds. A JSON save format is out of scope.
- **No change to what the data means.** Same keys, same types, same defaults, same merge rules.
- **No JavaScript-API change.** Scripts see the same objects whichever format a file came from.

## Today (measured 2026-10-27 on `main`)

- `upstream/oolite/Resources`: 85 `.plist` files — 84 OpenStep text, 1 XML.
- Parser: `oofnd` (`PListOldStyle.hpp`, `PListXML.hpp`, `PListParsing.hpp`), fuzzed against the old
  GNUstep behaviour by `tools/plist_fuzz.py` (0 unexplained divergences over 100k cases).
- Expansions: their files override or merge with core files of the same name through
  `ResourceManager` (`dictionaryFromFilesNamed…`, `arrayFromFilesNamed…`).

## Design (ADR-0065 has the decision; this is the shape)

1. **One data model.** JSON5 parses into the same `oo::PList` node tree the plist readers produce.
   Mapping rules:
   - object ↔ dictionary, array ↔ array, string ↔ string, `true`/`false` ↔ boolean,
     numbers ↔ integer/real (an integer literal stays an integer; anything with `.`/exponent is real).
   - OpenStep text plists are **untyped**: every scalar is a string until the reader asks for a
     number or boolean (`oo_intForKey:` etc.). JSON5 typed scalars are therefore a superset: the
     typed getters already accept strings, and they will accept real numbers/booleans unchanged.
   - `<data>` blobs: a JSON5 object `{ "$data": "<base64>" }`. Dates (XML only): `{ "$date": "<ISO 8601>" }`.
     Keys starting with `$` are reserved for these two forms; a core file never uses one today
     (checked by the converter).
2. **Lookup and merge.** For each file name the resource manager already searches (core
   `Resources/`, then each expansion in load order), it looks for `<name>.plist` **and**
   `<name>.json5`. If one directory has both, the JSON5 one wins and a warning is logged (an
   expansion should not ship both). Merging across directories is unchanged — it operates on the
   node tree, not the file format.
3. **Errors.** A JSON5 syntax error is logged with file, line and column, and the file is skipped,
   exactly as a plist syntax error is today.
4. **Converter.** `tools/plist2json5` (C++, built with the game, using the same `oofnd` reader and a
   new JSON5 writer) converts either way, preserves key order and comments where the source format
   has them (OpenStep `//` and `/* */` comments → JSON5 comments), and has a `--check` mode that
   proves a round trip is lossless.
5. **Core data migration is optional and last.** Whether the core game's own `Resources/` moves to
   JSON5 is Jon's call after items 1–4 ship; the default is **no** (both formats work, the core
   stays plist so diffs against upstream stay readable).

## Entry gate

- [ ] Phase 4 exit gate green (done 2026-10-21, oo-lqd).
- [ ] Jon approves this paper and ADR-0065 (the only human step).

## Exit gate

- [ ] `oofnd` JSON5 reader: unit tests for every mapping rule above, plus the JSON5 spec's own
      conformance suite (vendored test inputs), pass on Clang and GCC.
- [ ] Round trip: for every `.plist` under `upstream/oolite/Resources`, `plist2json5 --check` proves
      plist → JSON5 → node tree is identical to plist → node tree (exit 0 over all 85).
- [ ] Equivalence golden: the blessed goldens (001, 001-launch-dock) **reproduce byte-for-byte** when
      the core `Resources/` is replaced by its JSON5 conversion (a test-only resource tree; the
      shipped tree is unchanged).
- [ ] Mixed-format merge: a test expansion that ships `shipdata-overrides.json5` beside a core
      `shipdata.plist` produces the same merged node tree as the plist-only equivalent.
- [ ] Fuzz: `tools/plist_fuzz.py` gains a JSON5 mode (random node trees → JSON5 → parse → equal),
      100k cases, 0 divergences.
- [ ] Existing corpus/OXP tiers unchanged (plist-only expansions behave exactly as before).
- [ ] `docs/EXPANSION_MIGRATION.md` gains a "Writing data files in JSON5" section; human judgement:
      Jon reads it.

## Seams (frontier work)

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| JSON5 reader into `oo::PList` | `src/oofnd/PListJSON5.hpp/.cpp` + `tests/unit/oofnd/test_plist_json5.cpp` | frontier agent |
| Resource lookup for `.json5` | `ResourceManager` lookup change + component test | frontier agent |
| JSON5 writer + converter | `src/oofnd/PListWriting.hpp` (JSON5 arm), `tools/plist2json5` | frontier agent |

## Sweeps (fleet work)

None required. If Jon later chooses to migrate the core `Resources/`, it is one generated sweep
(one story per file, 85 stories) whose acceptance is `plist2json5 --check` plus the goldens.

## Work items

1. **5b.1** JSON5 reader (seam) — conformance suite, mapping-rule tests, fuzz mode.
2. **5b.2** JSON5 writer + `tools/plist2json5` with `--check`; round-trip all core plists.
3. **5b.3** Resource-manager lookup for `<name>.json5`, both-present rule, mixed-format merge test.
4. **5b.4** Equivalence golden run over a JSON5-converted resource tree (test-only).
5. **5b.5** Docs: `EXPANSION_MIGRATION.md` section; OXZ manifest note (`manifest.json5` accepted).
6. **5b.6** (optional, Jon's call) migrate core `Resources/` to JSON5.

## Risks

- **Two formats to support forever.** Mitigated by one node model: format code stops at the parser.
- **Upstream divergence.** Upstream Oolite has no JSON5 support; expansions that use `.json5` won't
  load on upstream builds. Expansion authors must be told (docs, verifier warning) — the OXP
  verifier gains a note "uses JSON5: requires Oolite ≥ <version>".
- **Semantics drift in typed scalars.** Covered by the mapping-rule tests and the equivalence golden.

## Open decisions (all have defaults; see ADR-0065)

| Question | Default |
|---|---|
| JSON5 vs JSON vs TOML vs YAML | JSON5 |
| Both formats in one directory | JSON5 wins, warning logged |
| Migrate core `Resources/` | No (optional item 5b.6) |
| Saved games | Stay XML plist |
| JSON5 library | Write our own small reader in `oofnd` (≈1k lines, fuzzed), no new dependency; fallback: vendor a header-only MIT library |

## Status log

- 2026-10-27: drafted at Jon's request ("draft another modernization paper … allow me to approve
  it"). Proposed only; no beads generated.
