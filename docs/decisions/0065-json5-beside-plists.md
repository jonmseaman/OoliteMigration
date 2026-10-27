# ADR-0065: JSON5 as a second data-file format beside property lists

- Status: Proposed — awaiting Jon's approval (not covered by the 2026-10-20 delegation: this changes
  the contract with expansion authors)
- Date: 2026-10-27
- Phase: [5b — Data formats](../phases/5b-data-formats.md) (proposed; runs in parallel with Phase 5)

## Context

Oolite's data files are NeXT/Apple property lists — 84 of the 85 core files in OpenStep text
form, one XML — and so are the data files of thousands of published expansions. After Phase 4 the
game parses them with its own C++ code in `oofnd`; nothing Objective-C remains behind the format.
The format is still unfamiliar to most modders' tools: no mainstream editor validates or formats
OpenStep plists, and the format is associated with a runtime the project has removed.

## Decision (proposed)

1. Add **JSON5** as an accepted format for every file the game reads as a property list, parsed
   into the same `oo::PList` node tree, with the mapping rules in the phase doc
   (`{ "$data": base64 }`, `{ "$date": ISO-8601 }`, `$`-prefixed keys reserved).
2. **Property lists remain supported indefinitely**, read exactly as today; nothing that loads now
   stops loading.
3. Resource lookup accepts `<name>.json5` wherever it accepts `<name>.plist`; if one directory has
   both, JSON5 wins and a warning is logged; cross-directory merging is format-independent.
4. Saved games stay XML property lists.
5. A converter `tools/plist2json5` with a lossless `--check` round trip ships with the game tools.
6. The core game's own `Resources/` stays plist unless Jon later decides otherwise.
7. Implementation is a small in-house reader/writer in `oofnd` (fuzzed), not a new dependency.

## Alternatives considered

- **JSON:** universal, but no comments; `descriptions.plist`-style hand-edited data needs them.
- **TOML:** good for flat config, awkward for Oolite's deep nesting (shipdata, AI state machines).
- **YAML:** readable but indentation-sensitive with implicit typing surprises; rejected.
- **Replace plists outright:** breaks every published expansion; rejected.
- **Do nothing:** costs nothing; plists already work without Objective-C. A valid choice if the
  modding-ergonomics gain is not worth a second format.

## Consequences

- Modders may write data in a format their editors understand; old expansions are untouched.
- The project supports two input formats forever (mitigated: one node model, format code confined
  to parsers, equivalence golden in the exit gate).
- Expansions that adopt JSON5 will not load on upstream (Objective-C) Oolite; the OXP verifier warns.

## Approval

Jon: approve, reject, or amend items 1–7. On approval this ADR becomes Accepted and the phase
doc's beads are generated.
